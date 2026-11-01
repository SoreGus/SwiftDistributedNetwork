//
//  DistributedNetworkError.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public enum DistributedNetworkError: LocalizedError, Codable, Sendable, Equatable {

    case connectionFailed
    case connectionClosed
    case connectionTimeout
    case actorNotFound
    case invalidMessage
    case serializationFailed
    case remoteInvocationFailed
    case remoteFailure(type: String, description: String)
    case unauthorized
    case internalFailure

    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            String(
                localized: "Failed to establish a connection."
            )

        case .connectionClosed:
            String(
                localized: "The connection was closed."
            )

        case .connectionTimeout:
            String(
                localized: "The connection timed out."
            )

        case .actorNotFound:
            String(
                localized: "The distributed actor was not found."
            )

        case .invalidMessage:
            String(
                localized: "The received message is invalid."
            )

        case .serializationFailed:
            String(
                localized: "Failed to serialize or deserialize the message."
            )

        case .remoteInvocationFailed:
            String(
                localized: "The remote invocation failed."
            )

        case .remoteFailure(let type, let description):
            "\(type): \(description)"

        case .unauthorized:
            String(
                localized: "The operation is not authorized."
            )

        case .internalFailure:
            String(
                localized: "An internal distributed system error occurred."
            )
        }
    }
}
