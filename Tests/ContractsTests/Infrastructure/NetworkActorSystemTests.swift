//
//  NetworkActorSystemTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation
import Testing
@testable import Contracts

private distributed actor TestCounter {

    typealias ActorSystem = NetworkActorSystem

    private var count = 0

    distributed func increment(
        amount: Int
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
}

struct NetworkActorSystemTests {

    @Test
    func systemAssignsActorIdentifier() {
        let system = NetworkActorSystem()

        let first = TestCounter(
            actorSystem: system
        )

        let second = TestCounter(
            actorSystem: system
        )

        #expect(first.id != second.id)
    }

    @Test
    func systemResolvesRegisteredLocalActor() throws {
        let system = NetworkActorSystem()

        let actor = TestCounter(
            actorSystem: system
        )

        let resolved = try system.resolve(
            id: actor.id,
            as: TestCounter.self
        )

        #expect(resolved != nil)
        #expect(resolved?.id == actor.id)
    }

    @Test
    func systemRemovesResignedActor() throws {
        let system = NetworkActorSystem()

        let actor = TestCounter(
            actorSystem: system
        )

        let identifier = actor.id

        system.resignID(
            identifier
        )

        let resolved = try system.resolve(
            id: identifier,
            as: TestCounter.self
        )

        #expect(resolved == nil)
    }

    @Test
    func systemExecutesLocalDistributedMethod() async throws {
        let system = NetworkActorSystem()

        let actor = TestCounter(
            actorSystem: system
        )

        let first = try await actor.increment(
            amount: 3
        )

        let second = try await actor.increment(
            amount: 2
        )

        #expect(first == 3)
        #expect(second == 5)
    }

    @Test
    func systemExecutesRemoteDistributedMethod() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try TestCounter.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        let result = try await remoteActor.increment(
            amount: 7
        )

        #expect(result == 7)

        let messages = await transport.sentMessages()

        #expect(messages.count == 1)
        #expect(messages.first?.kind == .request)
        #expect(messages.first?.actorID == hostActor.id)
    }

    @Test
    func systemExecutesRemoteVoidMethod() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        let initial = try await hostActor.increment(
            amount: 10
        )

        #expect(initial == 10)

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try TestCounter.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        try await remoteActor.reset()

        let result = try await hostActor.currentValue()

        #expect(result == 0)
    }

    @Test
    func systemRejectsRemoteCallWithoutTransport() async throws {
        let clientSystem = NetworkActorSystem()

        let unknownActor = try TestCounter.resolve(
            id: DistributedActorIdentifier(),
            using: clientSystem
        )

        await #expect(throws: DistributedNetworkError.connectionFailed) {
            try await unknownActor.increment(
                amount: 1
            )
        }
    }

    @Test
    func systemRejectsUnknownRemoteActor() async throws {
        let hostSystem = NetworkActorSystem()

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let unknownActor = try TestCounter.resolve(
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
                amount: 1
            )
        }
    }

    @Test
    func systemResolvesPublishedActorIdentifier() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        hostSystem.registerHostedActor(
            actor: hostActor
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let identifier = try await clientSystem.resolveRemoteActorID(
            actor: TestCounter.self
        )

        #expect(identifier == hostActor.id)

        let messages = await transport.sentMessages()

        #expect(messages.count == 1)
        #expect(messages.first?.kind == .request)
        #expect(messages.first?.actorID == nil)
    }

    @Test
    func systemExecutesAutomaticallyResolvedActor() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        hostSystem.registerHostedActor(
            actor: hostActor
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let identifier = try await clientSystem.resolveRemoteActorID(
            actor: TestCounter.self
        )

        let remoteActor = try TestCounter.resolve(
            id: identifier,
            using: clientSystem
        )

        let result = try await remoteActor.increment(
            amount: 12
        )

        #expect(result == 12)

        let messages = await transport.sentMessages()

        #expect(messages.count == 2)
        #expect(messages[0].actorID == nil)
        #expect(messages[1].actorID == hostActor.id)
    }

    @Test
    func systemRejectsActorLookupWithoutTransport() async {
        let system = NetworkActorSystem()

        await #expect(throws: DistributedNetworkError.connectionFailed) {
            try await system.resolveRemoteActorID(
                actor: TestCounter.self
            )
        }
    }

    @Test
    func systemRejectsUnpublishedActorLookup() async {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        await #expect(
            throws: DistributedNetworkError.remoteFailure(
                type: String(
                    reflecting: DistributedNetworkError.self
                ),
                description: "actorNotFound"
            )
        ) {
            try await clientSystem.resolveRemoteActorID(
                actor: TestCounter.self
            )
        }

        _ = hostActor
    }

    @Test
    func systemUnregistersPublishedActor() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        hostSystem.registerHostedActor(
            actor: hostActor
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let identifier = try await clientSystem.resolveRemoteActorID(
            actor: TestCounter.self
        )

        #expect(identifier == hostActor.id)

        hostSystem.unregisterHostedActor(
            typeName: String(
                reflecting: TestCounter.self
            ),
            actorID: hostActor.id
        )

        await #expect(
            throws: DistributedNetworkError.remoteFailure(
                type: String(
                    reflecting: DistributedNetworkError.self
                ),
                description: "actorNotFound"
            )
        ) {
            try await clientSystem.resolveRemoteActorID(
                actor: TestCounter.self
            )
        }
    }

    @Test
    func systemResigningActorRemovesPublication() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = TestCounter(
            actorSystem: hostSystem
        )

        hostSystem.registerHostedActor(
            actor: hostActor
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let identifier = try await clientSystem.resolveRemoteActorID(
            actor: TestCounter.self
        )

        #expect(identifier == hostActor.id)

        hostSystem.resignID(
            hostActor.id
        )

        await #expect(
            throws: DistributedNetworkError.remoteFailure(
                type: String(
                    reflecting: DistributedNetworkError.self
                ),
                description: "actorNotFound"
            )
        ) {
            try await clientSystem.resolveRemoteActorID(
                actor: TestCounter.self
            )
        }
    }

    @Test
    func systemReplacesPublishedActorOfSameType() async throws {
        let hostSystem = NetworkActorSystem()

        let firstActor = TestCounter(
            actorSystem: hostSystem
        )

        let secondActor = TestCounter(
            actorSystem: hostSystem
        )

        hostSystem.registerHostedActor(
            actor: firstActor
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let firstIdentifier = try await clientSystem.resolveRemoteActorID(
            actor: TestCounter.self
        )

        #expect(firstIdentifier == firstActor.id)

        hostSystem.registerHostedActor(
            actor: secondActor
        )

        let secondIdentifier = try await clientSystem.resolveRemoteActorID(
            actor: TestCounter.self
        )

        #expect(secondIdentifier == secondActor.id)
        #expect(firstIdentifier != secondIdentifier)
    }

    @Test
    func systemRejectsInvalidActorLookupPayload() async throws {
        let hostSystem = NetworkActorSystem()

        let message = DistributedMessage(
            kind: .request,
            payload: Data(
                [0xFF, 0x00, 0xFE]
            )
        )

        let response = await hostSystem.handle(
            message: message
        )

        #expect(response.id == message.id)
        #expect(response.kind == .failure)
        #expect(response.actorID == nil)
    }
}
