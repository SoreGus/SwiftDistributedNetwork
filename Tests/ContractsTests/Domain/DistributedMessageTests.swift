//
//  DistributedMessageTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
import Testing
@testable import Contracts

struct DistributedMessageTests {

    @Test
    func messagePreservesProperties() {
        let id = UUID()
        let actorID = DistributedActorIdentifier()
        let payload = Data()

        let message = DistributedMessage(
            id: id,
            kind: .request,
            actorID: actorID,
            payload: payload
        )

        #expect(message.id == id)
        #expect(message.kind == .request)
        #expect(message.actorID == actorID)
        #expect(message.payload == payload)
    }

    @Test
    func messagesSupportSerialization() throws {
        let original = DistributedMessage(
            kind: .request,
            actorID: DistributedActorIdentifier(),
            payload: Data(
                [1, 2, 3, 4]
            )
        )

        let data = try JSONEncoder().encode(
            original
        )

        let decoded = try JSONDecoder().decode(
            DistributedMessage.self,
            from: data
        )

        #expect(decoded == original)
    }

    @Test
    func responsesSupportSerializationWithoutActorID() throws {
        let original = DistributedMessage(
            kind: .response,
            payload: Data(
                [5, 6, 7, 8]
            )
        )

        let data = try JSONEncoder().encode(
            original
        )

        let decoded = try JSONDecoder().decode(
            DistributedMessage.self,
            from: data
        )

        #expect(decoded == original)
        #expect(decoded.actorID == nil)
    }

    @Test
    func messagesHaveUniqueIdentifiers() {
        let first = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        let second = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        #expect(first.id != second.id)
    }
}
