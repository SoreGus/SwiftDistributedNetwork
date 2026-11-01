//
//  NetworkInvocationDecoder.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation

public struct NetworkInvocationDecoder: DistributedTargetInvocationDecoder {

    public typealias SerializationRequirement = Codable

    private let invocation: NetworkInvocation
    private let registeredTypes: [String: Any.Type]
    private let actorSystem: NetworkActorSystem?

    private var argumentIndex = 0

    public init(
        invocation: NetworkInvocation,
        registeredTypes: [String: Any.Type] = [:],
        actorSystem: NetworkActorSystem? = nil
    ) {
        self.invocation = invocation
        self.registeredTypes = registeredTypes
        self.actorSystem = actorSystem
    }

    public mutating func decodeGenericSubstitutions() throws -> [Any.Type] {
        try invocation.genericSubstitutions.map { name in
            guard let type = registeredTypes[name] else {
                throw DistributedNetworkError.invalidMessage
            }

            return type
        }
    }

    public mutating func decodeNextArgument<Argument: SerializationRequirement>() throws -> Argument {
        guard argumentIndex < invocation.arguments.count else {
            throw DistributedNetworkError.invalidMessage
        }

        let data = invocation.arguments[argumentIndex]

        let decoder = JSONDecoder()

        if let actorSystem {
            decoder.userInfo[.actorSystemKey] = actorSystem
        }

        let value = try decoder.decode(
            Argument.self,
            from: data
        )

        argumentIndex += 1

        return value
    }

    public mutating func decodeReturnType() throws -> Any.Type? {
        nil
    }

    public mutating func decodeErrorType() throws -> Any.Type? {
        guard let name = invocation.errorType else {
            return nil
        }

        guard let type = registeredTypes[name] else {
            throw DistributedNetworkError.invalidMessage
        }

        return type
    }
}
