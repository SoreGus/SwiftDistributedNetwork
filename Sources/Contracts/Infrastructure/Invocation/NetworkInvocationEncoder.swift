//
//  NetworkInvocationEncoder.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation

public struct NetworkInvocationEncoder: DistributedTargetInvocationEncoder {

    public typealias SerializationRequirement = Codable

    private var genericSubstitutions: [String] = []
    private var arguments: [Data] = []
    private var returnType: String?
    private var errorType: String?

    public init() {}

    public mutating func recordGenericSubstitution<T>(
        _ type: T.Type
    ) throws {
        genericSubstitutions.append(
            String(
                reflecting: type
            )
        )
    }

    public mutating func recordArgument<Value: SerializationRequirement>(
        _ argument: RemoteCallArgument<Value>
    ) throws {
        let data = try JSONEncoder().encode(
            argument.value
        )

        arguments.append(
            data
        )
    }

    public mutating func recordReturnType<Res: SerializationRequirement>(
        _ resultType: Res.Type
    ) throws {
        returnType = String(
            reflecting: resultType
        )
    }

    public mutating func recordErrorType<E: Error>(
        _ type: E.Type
    ) throws {
        errorType = String(
            reflecting: type
        )
    }

    public mutating func doneRecording() throws {}

    public func makeInvocation() -> NetworkInvocation {
        NetworkInvocation(
            genericSubstitutions: genericSubstitutions,
            arguments: arguments,
            returnType: returnType,
            errorType: errorType
        )
    }
}
