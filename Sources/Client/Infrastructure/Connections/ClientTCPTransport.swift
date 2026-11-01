//
//  ClientTCPTransport.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Foundation
@preconcurrency import Network

actor ClientTCPTransport: DistributedTransportProtocol {

    private static let maximumMessageSize = 1_048_576
    private static let connectionTimeout: Duration = .seconds(10)

    private let connection: NWConnection
    private let queue: DispatchQueue

    private var started = false
    private var connected = false
    private var closed = false

    private var startContinuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(
        endpoint: NWEndpoint
    ) {
        self.connection = NWConnection(
            to: endpoint,
            using: .tcp
        )

        self.queue = DispatchQueue(
            label: "SwiftDistributedNetwork.Client.Connection"
        )
    }

    func connect() async throws(ClientConnectionError) {
        guard !closed else {
            throw .connectionClosed
        }

        guard !started else {
            if connected {
                return
            }

            throw .connectionFailed
        }

        started = true

        connection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.connectionDidChange(
                    state: state
                )
            }
        }

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in

                    startContinuation = continuation

                    timeoutTask = Task { [weak self] in
                        do {
                            try await Task.sleep(
                                for: Self.connectionTimeout
                            )

                            await self?.connectionTimedOut()
                        } catch {
                            return
                        }
                    }

                    connection.start(
                        queue: queue
                    )
                }
            } onCancel: {
                Task {
                    await self.close()
                }
            }

            guard !Task.isCancelled else {
                close()
                throw ClientConnectionError.cancelled
            }

            guard connected && !closed else {
                throw ClientConnectionError.connectionClosed
            }
        } catch {
            close()

            if let clientError = error as? ClientConnectionError {
                throw clientError
            }

            throw .connectionFailed
        }
    }

    func close() {
        guard !closed else {
            return
        }

        closed = true
        connected = false

        finishConnection(
            result: .failure(
                .cancelled
            )
        )

        connection.cancel()
    }

    private func connectionDidChange(
        state: NWConnection.State
    ) {
        guard !closed else {
            return
        }

        switch state {
        case .ready:
            connected = true

            finishConnection(
                result: .success(())
            )

        case .failed:
            connected = false
            closed = true

            finishConnection(
                result: .failure(
                    .connectionFailed
                )
            )

            connection.cancel()

        case .cancelled:
            connected = false
            closed = true

            finishConnection(
                result: .failure(
                    .connectionClosed
                )
            )

        default:
            break
        }
    }

    private func connectionTimedOut() {
        guard !connected,
              !closed,
              startContinuation != nil else {
            return
        }

        connected = false
        closed = true

        finishConnection(
            result: .failure(
                .connectionTimeout
            )
        )

        connection.cancel()
    }

    private func finishConnection(
        result: Result<Void, ClientConnectionError>
    ) {
        timeoutTask?.cancel()
        timeoutTask = nil

        guard let continuation = startContinuation else {
            return
        }

        startContinuation = nil

        continuation.resume(
            with: result
        )
    }

    func send(
        message: DistributedMessage
    ) async throws(DistributedNetworkError) {
        guard connected && !closed else {
            throw .connectionClosed
        }

        do {
            let payload = try JSONEncoder().encode(
                message
            )

            guard !payload.isEmpty,
                  payload.count <= Self.maximumMessageSize else {
                throw DistributedNetworkError.invalidMessage
            }

            let length = UInt32(
                payload.count
            )

            var frame = Data(
                [
                    UInt8((length >> 24) & 0xFF),
                    UInt8((length >> 16) & 0xFF),
                    UInt8((length >> 8) & 0xFF),
                    UInt8(length & 0xFF)
                ]
            )

            frame.append(
                payload
            )

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in

                connection.send(
                    content: frame,
                    completion: .contentProcessed { error in
                        if let error {
                            continuation.resume(
                                throwing: error
                            )
                        } else {
                            continuation.resume()
                        }
                    }
                )
            }
        } catch let error as DistributedNetworkError {
            throw error
        } catch {
            throw .connectionClosed
        }
    }

    func receive() async throws(DistributedNetworkError) -> DistributedMessage {
        guard connected && !closed else {
            throw .connectionClosed
        }

        do {
            let header = try await receiveBytes(
                count: 4
            )

            let length = header.reduce(
                UInt32(0)
            ) { partial, byte in
                (partial << 8) | UInt32(byte)
            }

            guard length > 0,
                  length <= UInt32(Self.maximumMessageSize) else {
                throw DistributedNetworkError.invalidMessage
            }

            let payload = try await receiveBytes(
                count: Int(length)
            )

            return try JSONDecoder().decode(
                DistributedMessage.self,
                from: payload
            )
        } catch let error as DistributedNetworkError {
            throw error
        } catch {
            throw .invalidMessage
        }
    }

    private func receiveBytes(
        count: Int
    ) async throws -> Data {
        var buffer = Data()

        while buffer.count < count {
            guard connected,
                  !closed,
                  !Task.isCancelled else {
                throw DistributedNetworkError.connectionClosed
            }

            let remaining = count - buffer.count

            let chunk = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Data, Error>) in

                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: min(
                        remaining,
                        65_536
                    )
                ) { data, context, isComplete, error in
                    if let error {
                        continuation.resume(
                            throwing: error
                        )
                        return
                    }

                    guard let data, !data.isEmpty else {
                        continuation.resume(
                            throwing: DistributedNetworkError.connectionClosed
                        )
                        return
                    }

                    continuation.resume(
                        returning: data
                    )
                }
            }

            buffer.append(
                chunk
            )
        }

        return buffer
    }
}
