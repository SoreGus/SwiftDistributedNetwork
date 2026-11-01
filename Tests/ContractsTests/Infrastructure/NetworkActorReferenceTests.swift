//
//  NetworkActorReferenceTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation
import Testing
@testable import Contracts

distributed actor ReferenceTestActor {

    typealias ActorSystem = NetworkActorSystem

    distributed func identify() -> Int {
        42
    }

    distributed func echo(
        actor reference: ReferenceTestActor
    ) -> ReferenceTestActor {
        reference
    }
}

struct NetworkActorReferenceTests {

    @Test
    func distributedActorReferencesSupportRoundTrip() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ReferenceTestActor(
            actorSystem: hostSystem
        )

        let referencedActor = ReferenceTestActor(
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

        let remoteActor = try ReferenceTestActor.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        let remoteReference = try ReferenceTestActor.resolve(
            id: referencedActor.id,
            using: clientSystem
        )

        let returnedReference = try await remoteActor.echo(
            actor: remoteReference
        )

        #expect(returnedReference.id == referencedActor.id)

        let value = try await returnedReference.identify()

        #expect(value == 42)

        let messages = await transport.sentMessages()

        #expect(messages.count == 2)
    }
}
