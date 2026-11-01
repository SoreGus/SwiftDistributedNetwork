//
//  NetworkInvocationTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation
import Testing
@testable import Contracts

struct NetworkInvocationTests {

    @Test
    func invocationSupportsSerialization() throws {
        var encoder = NetworkInvocationEncoder()

        try encoder.recordGenericSubstitution(
            Int.self
        )

        try encoder.recordArgument(
            RemoteCallArgument(
                label: "value",
                name: "value",
                value: 42
            )
        )

        try encoder.recordReturnType(
            String.self
        )

        try encoder.recordErrorType(
            Error.self
        )

        try encoder.doneRecording()

        let original = encoder.makeInvocation()

        let data = try JSONEncoder().encode(
            original
        )

        let decoded = try JSONDecoder().decode(
            NetworkInvocation.self,
            from: data
        )

        #expect(decoded == original)
    }

    @Test
    func encoderAndDecoderSupportRoundTrip() throws {
        var encoder = NetworkInvocationEncoder()

        try encoder.recordGenericSubstitution(
            Int.self
        )

        try encoder.recordArgument(
            RemoteCallArgument(
                label: "value",
                name: "value",
                value: 42
            )
        )

        try encoder.recordReturnType(
            String.self
        )

        try encoder.recordErrorType(
            Error.self
        )

        try encoder.doneRecording()

        let data = try JSONEncoder().encode(
            encoder.makeInvocation()
        )

        let invocation = try JSONDecoder().decode(
            NetworkInvocation.self,
            from: data
        )

        var decoder = NetworkInvocationDecoder(
            invocation: invocation,
            registeredTypes: [
                String(reflecting: Int.self): Int.self,
                String(reflecting: Error.self): Error.self
            ]
        )

        let types = try decoder.decodeGenericSubstitutions()

        #expect(types.count == 1)
        #expect(
            ObjectIdentifier(types[0]) == ObjectIdentifier(Int.self)
        )

        let value: Int = try decoder.decodeNextArgument()

        #expect(value == 42)

        let decodedErrorType = try decoder.decodeErrorType()

        let errorType = try #require(
            decodedErrorType
        )

        #expect(
            ObjectIdentifier(errorType) == ObjectIdentifier(Error.self)
        )
    }

    @Test
    func decoderRejectsMissingArguments() throws {
        let invocation = NetworkInvocation(
            genericSubstitutions: [],
            arguments: [],
            returnType: nil,
            errorType: nil
        )

        var decoder = NetworkInvocationDecoder(
            invocation: invocation
        )

        #expect(throws: DistributedNetworkError.invalidMessage) {
            let _: Int = try decoder.decodeNextArgument()
        }
    }

    @Test
    func decoderRejectsUnknownGenericTypes() throws {
        var encoder = NetworkInvocationEncoder()

        try encoder.recordGenericSubstitution(
            Int.self
        )

        let invocation = encoder.makeInvocation()

        var decoder = NetworkInvocationDecoder(
            invocation: invocation
        )

        #expect(throws: DistributedNetworkError.invalidMessage) {
            try decoder.decodeGenericSubstitutions()
        }
    }
}
