//
//  DistributedActorIdentifierTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
import Testing
@testable import Contracts

struct DistributedActorIdentifierTests {

    @Test
    func identifiersAreUnique() {
        let first = DistributedActorIdentifier()
        let second = DistributedActorIdentifier()

        #expect(first != second)
    }

    @Test
    func identifiersPreserveTheirValue() {
        let value = UUID()

        let identifier = DistributedActorIdentifier(
            value: value
        )

        #expect(identifier.value == value)
    }

    @Test
    func identifiersSupportSerialization() throws {
        let original = DistributedActorIdentifier()

        let data = try JSONEncoder().encode(
            original
        )

        let decoded = try JSONDecoder().decode(
            DistributedActorIdentifier.self,
            from: data
        )

        #expect(decoded == original)
    }
}
