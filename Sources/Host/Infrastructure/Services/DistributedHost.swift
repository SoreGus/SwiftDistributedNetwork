//
//  DistributedHost.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Distributed
import Foundation

public actor DistributedHost: DistributedHostProtocol {

    private enum State {
        case stopped
        case starting
        case running
        case stopping
    }

    public nonisolated let actorSystem: NetworkActorSystem

    private let serverService: HostServerService

    private var state: State = .stopped
    private var sessionID: UUID?
    private var publishedActorType: String?
    private var publishedActorID: DistributedActorIdentifier?
    private var stopTask: Task<Void, Never>?

    public init() {
        let actorSystem = NetworkActorSystem()

        self.actorSystem = actorSystem

        self.serverService = HostServerService(
            actorSystem: actorSystem
        )
    }

    public func start<Actor: DistributedActor>(
        actor: Actor,
        serviceName: String,
        serviceType: String,
        port: UInt16
    ) async throws(HostServerError) where Actor.ActorSystem == NetworkActorSystem {
        guard case .stopped = state else {
            throw .alreadyRunning
        }

        guard actor.actorSystem === actorSystem else {
            throw .invalidConfiguration
        }

        let identifier = UUID()

        let typeName = String(
            reflecting: Actor.self
        )

        let actorID = actor.id

        state = .starting
        sessionID = identifier

        publishedActorType = typeName
        publishedActorID = actorID

        actorSystem.registerHostedActor(
            actor: actor
        )

        do {
            try await serverService.start(
                configuration: HostServerConfiguration(
                    port: port,
                    serviceName: serviceName,
                    serviceType: serviceType
                )
            )

            guard sessionID == identifier,
                  case .starting = state,
                  !Task.isCancelled else {
                if sessionID == identifier {
                    await stop()
                }

                throw HostServerError.notRunning
            }

            state = .running
        } catch {
            if sessionID == identifier {
                await stop()
            }

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

        let identifier = sessionID
        let typeName = publishedActorType
        let actorID = publishedActorID

        let completion = Task {
            await serverService.stop()

            if let typeName, let actorID {
                actorSystem.unregisterHostedActor(
                    typeName: typeName,
                    actorID: actorID
                )
            }

            finishStopping(
                identifier: identifier
            )
        }

        stopTask = completion

        await completion.value
    }

    private func finishStopping(
        identifier: UUID?
    ) {
        guard case .stopping = state,
              sessionID == identifier else {
            return
        }

        publishedActorType = nil
        publishedActorID = nil
        sessionID = nil
        stopTask = nil

        state = .stopped
    }
}
