//
//  HostTestCounter.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Distributed
import Foundation
import Testing
@testable import Host

enum HostTestError: Error {
    case rejected
}

distributed actor HostTestCounter {

    typealias ActorSystem = NetworkActorSystem

    private var count = 0

    distributed func increment(
        by amount: Int
    ) -> Int {
        count += amount
        return count
    }

    distributed func reset() {
        count = 0
    }

    distributed func currentValue() -> Int {
        count
    }

    distributed func fail() throws -> Int {
        throw HostTestError.rejected
    }
}

@Suite(.serialized)
struct HostServerServiceTests {

    private func startServer(
        actorSystem: NetworkActorSystem,
        maximumConnections: Int = 32,
        maximumMessageSize: Int = 1_048_576
    ) async throws -> (HostServerService, UInt16) {
        let service = HostServerService(
            actorSystem: actorSystem
        )

        for _ in 0..<10 {
            let port = UInt16.random(
                in: 30_000...60_000
            )

            do {
                try await service.start(
                    configuration: HostServerConfiguration(
                        port: port,
                        serviceName: "SwiftDistributedNetworkTests",
                        maximumConnections: maximumConnections,
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

    @Test
    func serverRejectsInvalidConfiguration() async {
        let service = HostServerService(
            actorSystem: NetworkActorSystem()
        )

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await service.start(
                configuration: HostServerConfiguration(
                    port: 0
                )
            )
        }

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await service.start(
                configuration: HostServerConfiguration(
                    port: 8080,
                    maximumConnections: 0
                )
            )
        }

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await service.start(
                configuration: HostServerConfiguration(
                    port: 8080,
                    maximumMessageSize: 0
                )
            )
        }

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await service.start(
                configuration: HostServerConfiguration(
                    port: 8080,
                    serviceType: "invalid"
                )
            )
        }
    }

    @Test
    func serverRejectsDuplicateStart() async throws {
        let system = NetworkActorSystem()

        let (service, port) = try await startServer(
            actorSystem: system
        )

        await #expect(throws: HostServerError.alreadyRunning) {
            try await service.start(
                configuration: HostServerConfiguration(
                    port: port
                )
            )
        }

        await service.stop()
    }

    @Test
    func serverSupportsStartAndStop() async throws {
        let (service, port) = try await startServer(
            actorSystem: NetworkActorSystem()
        )

        let transport = try await HostTestTransport.connect(
            port: port
        )

        await transport.close()
        await service.stop()

        await service.stop()
    }

    @Test
    func serverSupportsRestart() async throws {
        let service = HostServerService(
            actorSystem: NetworkActorSystem()
        )

        let firstPort = UInt16.random(
            in: 30_000...45_000
        )

        try await service.start(
            configuration: HostServerConfiguration(
                port: firstPort
            )
        )

        await service.stop()

        let secondPort = UInt16.random(
            in: 45_001...60_000
        )

        try await service.start(
            configuration: HostServerConfiguration(
                port: secondPort
            )
        )

        let transport = try await HostTestTransport.connect(
            port: secondPort
        )

        await transport.close()
        await service.stop()
    }

    @Test
    func serverExecutesDistributedMethodOverTCP() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = HostTestCounter(
            actorSystem: hostSystem
        )

        let (service, port) = try await startServer(
            actorSystem: hostSystem
        )

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try HostTestCounter.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        let first = try await remoteActor.increment(
            by: 5
        )

        let second = try await remoteActor.increment(
            by: 3
        )

        #expect(first == 5)
        #expect(second == 8)

        await transport.close()
        await service.stop()
    }

    @Test
    func serverExecutesRemoteVoidMethodOverTCP() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = HostTestCounter(
            actorSystem: hostSystem
        )

        let (service, port) = try await startServer(
            actorSystem: hostSystem
        )

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try HostTestCounter.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        let initial = try await remoteActor.increment(
            by: 10
        )

        #expect(initial == 10)

        try await remoteActor.reset()

        let value = try await remoteActor.currentValue()

        #expect(value == 0)

        await transport.close()
        await service.stop()
    }

    @Test
    func serverPropagatesRemoteErrorsOverTCP() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = HostTestCounter(
            actorSystem: hostSystem
        )

        let (service, port) = try await startServer(
            actorSystem: hostSystem
        )

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try HostTestCounter.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        do {
            let _ = try await remoteActor.fail()

            Issue.record(
                "Expected a remote error."
            )
        } catch let error as DistributedNetworkError {
            guard case .remoteFailure(let type, let description) = error else {
                Issue.record(
                    "Unexpected distributed error: \(error)"
                )
                await transport.close()
                await service.stop()
                return
            }

            #expect(type == String(reflecting: HostTestError.self))
            #expect(description == "rejected")
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }

        await transport.close()
        await service.stop()
    }

    @Test
    func serverRejectsUnknownDistributedActorOverTCP() async throws {
        let hostSystem = NetworkActorSystem()

        let (service, port) = try await startServer(
            actorSystem: hostSystem
        )

        let transport = try await HostTestTransport.connect(
            port: port
        )

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let unknownActor = try HostTestCounter.resolve(
            id: DistributedActorIdentifier(),
            using: clientSystem
        )

        await #expect(
            throws: DistributedNetworkError.remoteFailure(
                type: String(
                    reflecting: DistributedNetworkError.self
                ),
                description: "actorNotFound"
            )
        ) {
            try await unknownActor.increment(
                by: 1
            )
        }

        await transport.close()
        await service.stop()
    }

    @Test
    func serverHandlesMultipleClients() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = HostTestCounter(
            actorSystem: hostSystem
        )

        let (service, port) = try await startServer(
            actorSystem: hostSystem
        )

        let firstTransport = try await HostTestTransport.connect(
            port: port
        )

        let secondTransport = try await HostTestTransport.connect(
            port: port
        )

        let firstSystem = NetworkActorSystem(
            transport: firstTransport
        )

        let secondSystem = NetworkActorSystem(
            transport: secondTransport
        )

        let firstActor = try HostTestCounter.resolve(
            id: hostActor.id,
            using: firstSystem
        )

        let secondActor = try HostTestCounter.resolve(
            id: hostActor.id,
            using: secondSystem
        )

        async let first = firstActor.increment(
            by: 2
        )

        async let second = secondActor.increment(
            by: 3
        )

        let firstResult = try await first
        let secondResult = try await second

        #expect(
            Set([firstResult, secondResult]) == Set([2, 5])
                || Set([firstResult, secondResult]) == Set([3, 5])
        )

        let finalValue = try await hostActor.currentValue()

        #expect(finalValue == 5)

        await firstTransport.close()
        await secondTransport.close()
        await service.stop()
    }
}
