//
//  HostServerError.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public enum HostServerError: LocalizedError, Sendable, Equatable {

    case alreadyRunning
    case notRunning
    case invalidConfiguration
    case startFailed(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            String(
                localized: "The host server is already running."
            )

        case .notRunning:
            String(
                localized: "The host server is not running."
            )

        case .invalidConfiguration:
            String(
                localized: "The host server configuration is invalid."
            )

        case .startFailed(let reason):
            String(
                localized: "Failed to start the host server: \(reason)"
            )
        }
    }
}
