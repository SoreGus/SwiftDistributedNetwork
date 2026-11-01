//
//  HostConnectionTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//


import Contracts
import Foundation
import Testing
@testable import Host

@Suite(.serialized)
struct HostConnectionTests {

    private func startServer(
        maximumMessageSize: Int = 1_048_576
    ) async throws -> (HostServerService, UInt16) {
        let service = HostServerService(
            actorSystem: NetworkActorSystem()
        )

        for _ in 0..<10 {
            let port = UInt16.random(
                in: 30_000...60_000
            )

            do {
                try await service.start(
                    configuration: HostServerConfiguration(
                        port: port,
                        serviceName: "SwiftDistributedNetworkFrameTests",
                        maximumMessageSize: maximumMessageSize
                    )
                )

                return (service, port)
            } catch HostServerError.startFailed {
                continue
            }
        }

        throw HostServerError.startFailed(
            "Could not find an available TCP port."
        )
    }

    private func makeFrame(
        message: DistributedMessage
    ) throws -> Data {
        let payload = try JSONEncoder().encode(
            message
        )

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

        return frame
    }

    @Test
    func connectionAcceptsFragmentedTCPFrame() async throws {
        let (service, port) = try await startServer()

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let request = DistributedMessage(
            kind: .request,
            actorID: DistributedActorIdentifier(),
            payload: Data()
        )

        let frame = try makeFrame(
            message: request
        )

        let firstChunk = Data(
            frame.prefix(2)
        )

        let secondChunk = Data(
            frame.dropFirst(2).prefix(5)
        )

        let thirdChunk = Data(
            frame.dropFirst(7)
        )

        try await transport.sendRaw(
            data: firstChunk
        )

        try await transport.sendRaw(
            data: secondChunk
        )

        try await transport.sendRaw(
            data: thirdChunk
        )

        let response = try await transport.receive()

        #expect(response.id == request.id)
        #expect(response.kind == .failure)

        let result = try JSONDecoder().decode(
            NetworkInvocationResult.self,
            from: response.payload
        )

        guard case .failure(let type, let description) = result else {
            Issue.record(
                "Expected actorNotFound failure."
            )

            await transport.close()
            await service.stop()
            return
        }

        #expect(type == String(reflecting: DistributedNetworkError.self))
        #expect(description == "actorNotFound")

        await transport.close()
        await service.stop()
    }

    @Test
    func connectionRejectsOversizedFrame() async throws {
        let (service, port) = try await startServer(
            maximumMessageSize: 128
        )

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let oversizedHeader = Data(
            [0, 0, 1, 0]
        )

        try await transport.sendRaw(
            data: oversizedHeader
        )

        await #expect(throws: DistributedNetworkError.connectionClosed) {
            try await transport.receive()
        }

        await transport.close()
        await service.stop()
    }

    @Test
    func connectionRejectsEmptyFrame() async throws {
        let (service, port) = try await startServer()

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let emptyHeader = Data(
            [0, 0, 0, 0]
        )

        try await transport.sendRaw(
            data: emptyHeader
        )

        await #expect(throws: DistributedNetworkError.connectionClosed) {
            try await transport.receive()
        }

        await transport.close()
        await service.stop()
    }
}
