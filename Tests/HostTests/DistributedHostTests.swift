//
//  DistributedHostTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Distributed
import Foundation
import Host
import Testing

private distributed actor TestHostActor {

    typealias ActorSystem = NetworkActorSystem

    distributed func value() -> Int {
        42
    }
}

@Suite(.serialized)
struct DistributedHostTests {

    private func startHost(
        host: DistributedHost,
        actor: TestHostActor
    ) async throws -> UInt16 {
        for _ in 0..<20 {
            let port = UInt16.random(
                in: 30_000...60_000
            )

            do {
                try await host.start(
                    actor: actor,
                    serviceName: "SwiftDistributedNetworkTests",
                    serviceType: "_sdntest._tcp",
                    port: port
                )

                return port
            } catch HostServerError.startFailed {
                continue
            }
        }

        throw HostServerError.startFailed(
            "Could not find an available port for the test server."
        )
    }

    private func lookup(
        actorSystem: NetworkActorSystem,
        actor: TestHostActor.Type
    ) async throws -> DistributedActorIdentifier {
        let payload = try JSONEncoder().encode(
            String(
                reflecting: actor
            )
        )

        let request = DistributedMessage(
            kind: .request,
            payload: payload
        )

        let response = await actorSystem.handle(
            message: request
        )

        #expect(response.id == request.id)
        #expect(response.kind == .response)

        return try JSONDecoder().decode(
            DistributedActorIdentifier.self,
            from: response.payload
        )
    }

    @Test
    func hostCreatesActorSystem() {
        let host = DistributedHost()

        let first = TestHostActor(
            actorSystem: host.actorSystem
        )

        let second = TestHostActor(
            actorSystem: host.actorSystem
        )

        #expect(first.actorSystem === host.actorSystem)
        #expect(second.actorSystem === host.actorSystem)
        #expect(first.id != second.id)
    }

    @Test
    func hostStartsAndStopsServer() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        await host.stop()
    }

    @Test
    func hostRegistersActorForRemoteLookup() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        let identifier = try await lookup(
            actorSystem: host.actorSystem,
            actor: TestHostActor.self
        )

        #expect(identifier == actor.id)

        await host.stop()
    }

    @Test
    func hostPreservesLocalDistributedExecution() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        let result = try await actor.value()

        #expect(result == 42)

        await host.stop()
    }

    @Test
    func hostRejectsActorFromDifferentActorSystem() async {
        let host = DistributedHost()

        let externalSystem = NetworkActorSystem()

        let actor = TestHostActor(
            actorSystem: externalSystem
        )

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await host.start(
                actor: actor,
                serviceName: "SwiftDistributedNetworkTests",
                serviceType: "_sdntest._tcp",
                port: 50_000
            )
        }
    }

    @Test
    func hostRejectsInvalidPort() async {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await host.start(
                actor: actor,
                serviceName: "SwiftDistributedNetworkTests",
                serviceType: "_sdntest._tcp",
                port: 0
            )
        }

        await host.stop()
    }

    @Test
    func hostRejectsInvalidServiceType() async {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        await #expect(throws: HostServerError.invalidConfiguration) {
            try await host.start(
                actor: actor,
                serviceName: "SwiftDistributedNetworkTests",
                serviceType: "invalid",
                port: 50_000
            )
        }

        await host.stop()
    }

    @Test
    func hostRejectsSecondStart() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        let port = try await startHost(
            host: host,
            actor: actor
        )

        await #expect(throws: HostServerError.alreadyRunning) {
            try await host.start(
                actor: actor,
                serviceName: "SwiftDistributedNetworkTests",
                serviceType: "_sdntest._tcp",
                port: port
            )
        }

        await host.stop()
    }

    @Test
    func hostRemovesPublicationAfterStop() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        let identifier = try await lookup(
            actorSystem: host.actorSystem,
            actor: TestHostActor.self
        )

        #expect(identifier == actor.id)

        await host.stop()

        let payload = try JSONEncoder().encode(
            String(
                reflecting: TestHostActor.self
            )
        )

        let request = DistributedMessage(
            kind: .request,
            payload: payload
        )

        let response = await host.actorSystem.handle(
            message: request
        )

        #expect(response.kind == .failure)
        #expect(response.id == request.id)
    }

    @Test
    func hostSupportsRepeatedStop() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        await host.stop()
        await host.stop()
        await host.stop()
    }

    @Test
    func hostSupportsConcurrentStop() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        await withTaskGroup(
            of: Void.self
        ) { group in
            for _ in 0..<10 {
                group.addTask {
                    await host.stop()
                }
            }

            await group.waitForAll()
        }
    }

    @Test
    func hostSupportsRestart() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        let firstIdentifier = try await lookup(
            actorSystem: host.actorSystem,
            actor: TestHostActor.self
        )

        #expect(firstIdentifier == actor.id)

        await host.stop()

        _ = try await startHost(
            host: host,
            actor: actor
        )

        let secondIdentifier = try await lookup(
            actorSystem: host.actorSystem,
            actor: TestHostActor.self
        )

        #expect(secondIdentifier == actor.id)

        await host.stop()
    }

    @Test
    func hostDoesNotRemoveActorFromActorSystemOnStop() async throws {
        let host = DistributedHost()

        let actor = TestHostActor(
            actorSystem: host.actorSystem
        )

        _ = try await startHost(
            host: host,
            actor: actor
        )

        await host.stop()

        let resolved = try host.actorSystem.resolve(
            id: actor.id,
            as: TestHostActor.self
        )

        #expect(resolved?.id == actor.id)
    }
}
