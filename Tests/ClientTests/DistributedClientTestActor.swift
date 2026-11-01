//
//  DistributedClientTestActor.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Client
import Contracts
import Distributed
import Foundation
import Host
import Testing

private enum DistributedClientTestError: Error {
    case rejected
}

private distributed actor DistributedClientTestActor {

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
        throw DistributedClientTestError.rejected
    }
}

private distributed actor UnpublishedClientTestActor {

    typealias ActorSystem = NetworkActorSystem

    distributed func value() -> Int {
        42
    }
}

@Suite(.serialized)
struct DistributedClientTests {

    private let serviceType = "_sdntest._tcp"

    private func withHost<ResultValue: Sendable>(
        operation: @Sendable (
            DistributedClientTestActor,
            String
        ) async throws -> ResultValue
    ) async throws -> ResultValue {
        let host = DistributedHost()

        let actor = DistributedClientTestActor(
            actorSystem: host.actorSystem
        )

        let serviceName = "SDNClient-\(UUID().uuidString.prefix(8))"

        var started = false

        for _ in 0..<20 {
            let port = UInt16.random(
                in: 30_000...60_000
            )

            do {
                try await host.start(
                    actor: actor,
                    serviceName: serviceName,
                    serviceType: serviceType,
                    port: port
                )

                started = true
                break
            } catch HostServerError.startFailed {
                continue
            }
        }

        guard started else {
            throw HostServerError.startFailed(
                "Could not start the test Host."
            )
        }

        do {
            let result = try await operation(
                actor,
                serviceName
            )

            await host.stop()

            return result
        } catch {
            await host.stop()
            throw error
        }
    }

    @Test
    func clientRejectsInvalidServiceName() async {
        let client = DistributedClient()

        await #expect(throws: ClientConnectionError.invalidEndpoint) {
            try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: "",
                serviceType: "_sdntest._tcp"
            )
        }

        await client.disconnect()
    }

    @Test
    func clientRejectsInvalidServiceType() async {
        let client = DistributedClient()

        await #expect(throws: ClientConnectionError.invalidEndpoint) {
            try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: "ControlCenter",
                serviceType: "invalid"
            )
        }

        await client.disconnect()
    }

    @Test
    func clientConnectsAndResolvesActorAutomatically() async throws {
        try await withHost { hostActor, serviceName in
            let client = DistributedClient()

            let remoteActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            #expect(remoteActor.id == hostActor.id)

            await client.disconnect()
        }
    }

    @Test
    func clientExecutesRemoteMethodWithParameters() async throws {
        try await withHost { hostActor, serviceName in
            let client = DistributedClient()

            let remoteActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            let first = try await remoteActor.increment(
                amount: 5
            )

            let second = try await remoteActor.increment(
                amount: 3
            )

            let hostValue = try await hostActor.currentValue()

            #expect(first == 5)
            #expect(second == 8)
            #expect(hostValue == 8)

            await client.disconnect()
        }
    }

    @Test
    func clientExecutesRemoteVoidMethod() async throws {
        try await withHost { hostActor, serviceName in
            let client = DistributedClient()

            let remoteActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            let initial = try await remoteActor.increment(
                amount: 10
            )

            #expect(initial == 10)

            try await remoteActor.reset()

            let value = try await hostActor.currentValue()

            #expect(value == 0)

            await client.disconnect()
        }
    }

    @Test
    func clientReceivesRemoteMethodFailure() async throws {
        try await withHost { _, serviceName in
            let client = DistributedClient()

            let remoteActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            do {
                _ = try await remoteActor.fail()

                Issue.record(
                    "Expected the remote method to throw."
                )
            } catch let error as DistributedNetworkError {
                guard case .remoteFailure = error else {
                    Issue.record(
                        "Expected a remoteFailure, received \(error)."
                    )

                    await client.disconnect()
                    return
                }
            } catch {
                Issue.record(
                    "Unexpected error: \(error)"
                )
            }

            await client.disconnect()
        }
    }

    @Test
    func clientRejectsUnpublishedActorType() async throws {
        try await withHost { _, serviceName in
            let client = DistributedClient()

            await #expect(throws: ClientConnectionError.connectionFailed) {
                try await client.connect(
                    actor: UnpublishedClientTestActor.self,
                    serviceName: serviceName,
                    serviceType: "_sdntest._tcp"
                )
            }

            await client.disconnect()
        }
    }

    @Test
    func clientClosesRemoteConnectionAfterDisconnect() async throws {
        try await withHost { _, serviceName in
            let client = DistributedClient()

            let remoteActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            let initial = try await remoteActor.currentValue()

            #expect(initial == 0)

            await client.disconnect()

            await #expect(throws: DistributedNetworkError.connectionClosed) {
                try await remoteActor.increment(
                    amount: 1
                )
            }
        }
    }

    @Test
    func clientSupportsReconnect() async throws {
        try await withHost { hostActor, serviceName in
            let client = DistributedClient()

            let firstActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            let firstValue = try await firstActor.increment(
                amount: 4
            )

            #expect(firstValue == 4)

            await client.disconnect()

            let secondActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
            )

            let secondValue = try await secondActor.increment(
                amount: 3
            )

            #expect(secondValue == 7)
            #expect(secondActor.id == hostActor.id)

            await client.disconnect()
        }
    }

    @Test
    func clientSupportsConcurrentRemoteCalls() async throws {
        try await withHost { hostActor, serviceName in
            let client = DistributedClient()

            let remoteActor = try await client.connect(
                actor: DistributedClientTestActor.self,
                serviceName: serviceName,
                serviceType: "_sdntest._tcp"
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

            let finalValue = try await hostActor.currentValue()

            #expect(finalValue == 20)

            await client.disconnect()
        }
    }

    @Test
    func clientSupportsRepeatedDisconnect() async {
        let client = DistributedClient()

        await client.disconnect()
        await client.disconnect()
        await client.disconnect()
    }
}
