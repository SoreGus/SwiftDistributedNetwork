//
//  HostServerService.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Foundation
@preconcurrency import Network

public actor HostServerService: HostServerServiceProtocol {

    private enum State {
        case stopped
        case starting
        case running
        case stopping
    }

    private let actorSystem: NetworkActorSystem
    private let queue: DispatchQueue

    private var state: State = .stopped
    private var listener: NWListener?
    private var listenerID: UUID?
    private var configuration: HostServerConfiguration?

    private var startContinuation: CheckedContinuation<Void, Error>?
    private var stopTask: Task<Void, Never>?

    private var connections: [UUID: HostConnection] = [:]
    private var connectionTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        actorSystem: NetworkActorSystem
    ) {
        self.actorSystem = actorSystem

        self.queue = DispatchQueue(
            label: "SwiftDistributedNetwork.Host.Server"
        )
    }

    public func start(
        configuration: HostServerConfiguration
    ) async throws(HostServerError) {
        guard case .stopped = state else {
            throw .alreadyRunning
        }

        guard configuration.port != 0,
              configuration.maximumConnections > 0,
              configuration.maximumMessageSize > 0,
              configuration.maximumMessageSize <= Int(UInt32.max),
              configuration.serviceType.hasPrefix("_"),
              configuration.serviceType.hasSuffix("._tcp") else {
            throw .invalidConfiguration
        }

        guard let port = NWEndpoint.Port(
            rawValue: configuration.port
        ) else {
            throw .invalidConfiguration
        }

        let newListener: NWListener

        do {
            newListener = try NWListener(
                using: .tcp,
                on: port
            )
        } catch {
            throw .startFailed(
                String(
                    describing: error
                )
            )
        }

        let identifier = UUID()

        newListener.service = NWListener.Service(
            name: configuration.serviceName,
            type: configuration.serviceType
        )

        newListener.newConnectionLimit = configuration.maximumConnections

        newListener.stateUpdateHandler = { [weak self] listenerState in
            Task {
                await self?.listenerDidChange(
                    id: identifier,
                    listenerState: listenerState
                )
            }
        }

        newListener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.accept(
                    id: identifier,
                    connection: connection
                )
            }
        }

        listener = newListener
        listenerID = identifier
        self.configuration = configuration
        state = .starting

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in

                    startContinuation = continuation

                    newListener.start(
                        queue: queue
                    )
                }
            } onCancel: {
                Task {
                    await self.stop()
                }
            }

            try Task.checkCancellation()
        } catch {
            await stop()

            if let hostError = error as? HostServerError {
                throw hostError
            }

            throw .startFailed(
                String(
                    describing: error
                )
            )
        }
    }

    public func stop() async {
        switch state {
        case .stopped:
            return

        case .stopping:
            if let stopTask {
                await stopTask.value
            }

            return

        case .starting, .running:
            state = .stopping
        }

        let identifier = listenerID

        listenerID = nil
        configuration = nil

        listener?.cancel()
        listener = nil

        if let continuation = startContinuation {
            startContinuation = nil

            continuation.resume(
                throwing: HostServerError.notRunning
            )
        }

        let activeConnections = Array(
            connections.values
        )

        let activeTasks = Array(
            connectionTasks.values
        )

        let completion = Task { [weak self] in
            for connection in activeConnections {
                await connection.stop()
            }

            for task in activeTasks {
                await task.value
            }

            await self?.finishStopping(
                identifier: identifier
            )
        }

        stopTask = completion

        await completion.value
    }

    private func finishStopping(
        identifier: UUID?
    ) {
        guard case .stopping = state else {
            return
        }

        connections.removeAll()
        connectionTasks.removeAll()

        stopTask = nil
        state = .stopped
    }

    private func listenerDidChange(
        id: UUID,
        listenerState: NWListener.State
    ) {
        guard listenerID == id else {
            return
        }

        switch listenerState {
        case .ready:
            guard case .starting = state else {
                return
            }

            state = .running

            if let continuation = startContinuation {
                startContinuation = nil
                continuation.resume()
            }

        case .failed(let error):
            let failure = HostServerError.startFailed(
                String(
                    describing: error
                )
            )

            if let continuation = startContinuation {
                startContinuation = nil

                continuation.resume(
                    throwing: failure
                )
            }

            Task {
                await stop()
            }

        case .cancelled:
            if let continuation = startContinuation {
                startContinuation = nil

                continuation.resume(
                    throwing: HostServerError.notRunning
                )
            }

            Task {
                await stop()
            }

        default:
            break
        }
    }

    private func accept(
        id: UUID,
        connection: NWConnection
    ) {
        guard listenerID == id,
              case .running = state,
              let configuration,
              connections.count < configuration.maximumConnections else {
            connection.cancel()
            return
        }

        let connectionID = UUID()

        let hostConnection = HostConnection(
            connection: connection,
            actorSystem: actorSystem,
            maximumMessageSize: configuration.maximumMessageSize
        )

        connections[connectionID] = hostConnection

        connectionTasks[connectionID] = Task {
            await hostConnection.run()

            removeConnection(
                id: connectionID
            )
        }
    }

    private func removeConnection(
        id: UUID
    ) {
        connections.removeValue(
            forKey: id
        )

        connectionTasks.removeValue(
            forKey: id
        )
    }
}
