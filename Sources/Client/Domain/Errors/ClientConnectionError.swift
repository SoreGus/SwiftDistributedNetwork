//
//  ClientConnectionError.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public enum ClientConnectionError: LocalizedError, Sendable, Equatable {

    case invalidEndpoint
    case connectionFailed
    case connectionTimeout
    case connectionClosed
    case notConnected
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            String(
                localized: "The server endpoint is invalid."
            )

        case .connectionFailed:
            String(
                localized: "Failed to connect to the server."
            )

        case .connectionTimeout:
            String(
                localized: "The connection timed out."
            )

        case .connectionClosed:
            String(
                localized: "The server connection was closed."
            )

        case .notConnected:
            String(
                localized: "The client is not connected."
            )

        case .cancelled:
            String(
                localized: "The connection was cancelled."
            )
        }
    }
}
