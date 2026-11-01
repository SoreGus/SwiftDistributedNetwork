//
//  DistributedClientProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Distributed

public protocol DistributedClientProtocol: Sendable {

    func connect<Actor: DistributedActor>(
        actor: Actor.Type,
        serviceName: String,
        serviceType: String
    ) async throws(ClientConnectionError) -> Actor where Actor.ActorSystem == NetworkActorSystem

    func disconnect() async
}

