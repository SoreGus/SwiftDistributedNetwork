//
//  ClientServerEndpoint.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public enum ClientServerEndpoint: Hashable, Sendable {

    case bonjour(
        name: String,
        type: String,
        domain: String
    )

    case host(
        name: String,
        port: UInt16
    )
}
