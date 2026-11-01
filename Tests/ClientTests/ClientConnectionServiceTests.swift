//
//  ClientConnectionServiceTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Client
import Contracts
import Distributed
import Foundation
import Testing

enum ClientTestError: Error {
    case rejected
}

distributed actor ClientTestCounter {

    typealias ActorSystem = NetworkActorSystem

    private var count = 0

    distributed func increment(
        amount: Int
    ) -> Int {
        count += amount
        return count
    }

    distributed func currentValue() -> Int {
        count
    }

    distributed func reset() {
        count = 0
    }

    distributed func fail() throws -> Int {
        throw ClientTestError.rejected
    }
}

@Suite(.serialized)
struct ClientConnectionServiceTests {

    @Test
    func connectionRejectsInvalidEndpoints() async {
        let service = ClientConnectionService()

        await #expect(throws: ClientConnectionError.invalidEndpoint) {
            try await service.connect(
                endpoint: .host(
                    name: "",
                    port: 8080
                )
            )
        }

        await #expect(throws: ClientConnectionError.invalidEndpoint) {
            try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: 0
                )
            )
        }

        await #expect(throws: ClientConnectionError.invalidEndpoint) {
            try await service.connect(
                endpoint: .bonjour(
                    name: "",
                    type: "_application._tcp",
                    domain: "local."
                )
            )
        }
    }

    @Test
    func connectionExecutesDistributedMethodsOverTCP() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let clientSystem = try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: port
                )
            )

            let remoteActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: clientSystem
            )

            let first = try await remoteActor.increment(
                amount: 5
            )

            let second = try await remoteActor.increment(
                amount: 3
            )

            #expect(first == 5)
            #expect(second == 8)

            await service.disconnect()
        }
    }

    @Test
    func connectionExecutesRemoteVoidMethod() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let clientSystem = try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: port
                )
            )

            let remoteActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: clientSystem
            )

            let initial = try await remoteActor.increment(
                amount: 10
            )

            #expect(initial == 10)

            try await remoteActor.reset()

            let value = try await remoteActor.currentValue()

            #expect(value == 0)

            await service.disconnect()
        }
    }

    @Test
    func connectionPreservesRemoteErrorInformation() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let clientSystem = try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: port
                )
            )

            let remoteActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: clientSystem
            )

            do {
                let value = try await remoteActor.fail()

                Issue.record(
                    "Expected a remote error, received \(value)."
                )
            } catch let error as DistributedNetworkError {
                guard case .remoteFailure(let type, let description) = error else {
                    Issue.record(
                        "Expected remoteFailure, received \(error)."
                    )
                    await service.disconnect()
                    return
                }

                #expect(type == String(reflecting: ClientTestError.self))
                #expect(description == "rejected")
            } catch {
                Issue.record(
                    "Unexpected error: \(error)"
                )
            }

            await service.disconnect()
        }
    }

    @Test
    func connectionRejectsUnknownRemoteActor() async throws {
        let hostSystem = NetworkActorSystem()

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let clientSystem = try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: port
                )
            )

            let remoteActor = try ClientTestCounter.resolve(
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
                try await remoteActor.increment(
                    amount: 1
                )
            }

            await service.disconnect()
        }
    }

    @Test
    func connectionSupportsConcurrentDistributedCalls() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let clientSystem = try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: port
                )
            )

            let remoteActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: clientSystem
            )

            let results = try await withThrowingTaskGroup(
                of: Int.self,
                returning: [Int].self
            ) { group in
                for _ in 0..<20 {
                    group.addTask {
                        try await remoteActor.increment(
                            amount: 1
                        )
                    }
                }

                var values: [Int] = []

                for try await value in group {
                    values.append(
                        value
                    )
                }

                return values
            }

            #expect(results.count == 20)
            #expect(results.sorted() == Array(1...20))

            let finalValue = try await remoteActor.currentValue()

            #expect(finalValue == 20)

            await service.disconnect()
        }
    }

    @Test
    func connectionStopsRemoteCallsAfterDisconnect() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let clientSystem = try await service.connect(
                endpoint: .host(
                    name: "127.0.0.1",
                    port: port
                )
            )

            let remoteActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: clientSystem
            )

            let initial = try await remoteActor.currentValue()

            #expect(initial == 0)

            await service.disconnect()

            await #expect(throws: DistributedNetworkError.connectionClosed) {
                try await remoteActor.increment(
                    amount: 1
                )
            }
        }
    }

    @Test
    func connectionSupportsReconnect() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let endpoint = ClientServerEndpoint.host(
                name: "127.0.0.1",
                port: port
            )

            let firstSystem = try await service.connect(
                endpoint: endpoint
            )

            let firstActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: firstSystem
            )

            let firstValue = try await firstActor.increment(
                amount: 4
            )

            #expect(firstValue == 4)

            await service.disconnect()

            let secondSystem = try await service.connect(
                endpoint: endpoint
            )

            let secondActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: secondSystem
            )

            let secondValue = try await secondActor.increment(
                amount: 3
            )

            #expect(secondValue == 7)

            await service.disconnect()
        }
    }

    @Test
    func connectionReplacesPreviousSession() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        try await ClientTestHost.run(
            actorSystem: hostSystem
        ) { port in
            let service = ClientConnectionService()

            let endpoint = ClientServerEndpoint.host(
                name: "127.0.0.1",
                port: port
            )

            let firstSystem = try await service.connect(
                endpoint: endpoint
            )

            let firstActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: firstSystem
            )

            let secondSystem = try await service.connect(
                endpoint: endpoint
            )

            let secondActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: secondSystem
            )

            await #expect(throws: DistributedNetworkError.connectionClosed) {
                try await firstActor.increment(
                    amount: 1
                )
            }

            let value = try await secondActor.increment(
                amount: 2
            )

            #expect(value == 2)

            await service.disconnect()
        }
    }
}
