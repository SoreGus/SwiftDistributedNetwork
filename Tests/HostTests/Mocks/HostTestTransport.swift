//
//  HostTestTransport.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Foundation
import Synchronization
@preconcurrency import Network

actor HostTestTransport: DistributedTransportProtocol {

    private let connection: NWConnection
    private let queue: DispatchQueue

    private init(
        connection: NWConnection
    ) {
        self.connection = connection
        self.queue = DispatchQueue(
            label: "SwiftDistributedNetwork.Tests.Transport"
        )
    }

    static func connect(
        port: UInt16
    ) async throws -> HostTestTransport {
        guard let endpointPort = NWEndpoint.Port(
            rawValue: port
        ) else {
            throw DistributedNetworkError.connectionFailed
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(
                "127.0.0.1"
            ),
            port: endpointPort,
            using: .tcp
        )

        let transport = HostTestTransport(
            connection: connection
        )

        try await transport.start()

        return transport
    }

    private func start() async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            let pending = Mutex<CheckedContinuation<Void, Error>?>(
                continuation
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let completion = pending.withLock { value in
                        let completion = value
                        value = nil
                        return completion
                    }

                    completion?.resume()

                case .failed(let error):
                    let completion = pending.withLock { value in
                        let completion = value
                        value = nil
                        return completion
                    }

                    completion?.resume(
                        throwing: error
                    )

                case .cancelled:
                    let completion = pending.withLock { value in
                        let completion = value
                        value = nil
                        return completion
                    }

                    completion?.resume(
                        throwing: DistributedNetworkError.connectionClosed
                    )

                default:
                    break
                }
            }

            connection.start(
                queue: queue
            )
        }
    }

    func send(
        message: DistributedMessage
    ) async throws(DistributedNetworkError) {
        do {
            let payload = try JSONEncoder().encode(
                message
            )

            guard !payload.isEmpty,
                  payload.count <= Int(UInt32.max) else {
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

            try await sendRaw(
                data: frame
            )
        } catch let error as DistributedNetworkError {
            throw error
        } catch {
            throw .connectionFailed
        }
    }

    func receive() async throws(DistributedNetworkError) -> DistributedMessage {
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
                  length <= 1_048_576 else {
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
            throw .connectionClosed
        }
    }

    func sendRaw(
        data: Data
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in

            connection.send(
                content: data,
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

    private func receiveBytes(
        count: Int
    ) async throws -> Data {
        var buffer = Data()

        while buffer.count < count {
            let remaining = count - buffer.count

            let chunk = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Data, Error>) in

                connection.receive(
                    minimumIncompleteLength: 1,
                    maximumLength: min(
                        remaining,
                        65_536
                    )
                ) { data, _, _, error in
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

    func close() {
        connection.cancel()
    }
}
