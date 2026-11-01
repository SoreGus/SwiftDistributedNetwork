//
//  ClientDiscoveryServiceProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

public protocol ClientDiscoveryServiceProtocol: Sendable {

    func discover(
        serviceType: String
    ) async -> AsyncStream<[ClientServerEndpoint]>
}
