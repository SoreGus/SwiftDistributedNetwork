//
//  DistributedNetworkErrorTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
import Testing
@testable import Contracts

struct DistributedNetworkErrorTests {

    @Test
    func errorsSupportSerialization() throws {
        let original = DistributedNetworkError.actorNotFound

        let data = try JSONEncoder().encode(
            original
        )

        let decoded = try JSONDecoder().decode(
            DistributedNetworkError.self,
            from: data
        )

        #expect(decoded == original)
    }

    @Test
    func errorsSupportEquality() {
        let first = DistributedNetworkError.connectionFailed
        let second = DistributedNetworkError.connectionFailed

        #expect(first == second)
        #expect(first != .connectionTimeout)
    }
    
    @Test
    func errorsProvideLocalizedDescriptions() {
        let errors: [DistributedNetworkError] = [
            .connectionFailed,
            .connectionClosed,
            .connectionTimeout,
            .actorNotFound,
            .invalidMessage,
            .serializationFailed,
            .remoteInvocationFailed,
            .unauthorized,
            .internalFailure
        ]

        for error in errors {
            #expect(!error.localizedDescription.isEmpty)
        }
    }
}
