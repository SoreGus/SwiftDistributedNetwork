//
//  ClientConnectionServiceProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts

public protocol ClientConnectionServiceProtocol: Sendable {

    func connect(
        endpoint: ClientServerEndpoint
    ) async throws(ClientConnectionError) -> NetworkActorSystem

    func disconnect() async
}
