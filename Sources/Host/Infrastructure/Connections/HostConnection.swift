//
//  HostConnection.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Foundation
@preconcurrency import Network

actor HostConnection {

    private enum ConnectionError: Error {
        case closed
        case invalidFrame
    }

    private let connection: NWConnection
    private let actorSystem: NetworkActorSystem
    private let queue: DispatchQueue
    private let maximumMessageSize: Int

    private var stopped = false

    init(
        connection: NWConnection,
        actorSystem: NetworkActorSystem,
        maximumMessageSize: Int
    ) {
        self.connection = connection
        self.actorSystem = actorSystem
        self.maximumMessageSize = maximumMessageSize

        self.queue = DispatchQueue(
            label: "SwiftDistributedNetwork.Host.Connection"
        )
    }

    func run() async {
        guard !stopped else {
            connection.cancel()
            return
        }

        connection.start(
            queue: queue
        )

        defer {
            stopped = true
            connection.cancel()
        }

        do {
            while !stopped && !Task.isCancelled {
                let message = try await receiveMessage()

                guard !stopped && !Task.isCancelled else {
                    break
                }

                let response = await actorSystem.handle(
                    message: message
                )

                guard !stopped && !Task.isCancelled else {
                    break
                }

                try await sendMessage(
                    message: response
                )
            }
        } catch {
            stopped = true
        }
    }

    func stop() {
        stopped = true
        connection.cancel()
    }

    private func receiveMessage() async throws -> DistributedMessage {
        let header = try await receiveBytes(
            count: 4
        )

        let length = header.reduce(
            UInt32(0)
        ) { partial, byte in
            (partial << 8) | UInt32(byte)
        }

        guard length > 0,
              length <= UInt32(maximumMessageSize) else {
            throw ConnectionError.invalidFrame
        }

        let payload = try await receiveBytes(
            count: Int(length)
        )

        return try JSONDecoder().decode(
            DistributedMessage.self,
            from: payload
        )
    }

    private func receiveBytes(
        count: Int
    ) async throws -> Data {
        var buffer = Data()

        while buffer.count < count {
            guard !stopped && !Task.isCancelled else {
                throw ConnectionError.closed
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
                ) { data, _, isComplete, error in
                    if let error {
                        continuation.resume(
                            throwing: error
                        )
                        return
                    }

                    guard let data, !data.isEmpty else {
                        continuation.resume(
                            throwing: ConnectionError.closed
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

    private func sendMessage(
        message: DistributedMessage
    ) async throws {
        let payload = try JSONEncoder().encode(
            message
        )

        guard !payload.isEmpty,
              payload.count <= maximumMessageSize else {
            throw ConnectionError.invalidFrame
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
    }
}
