//
//  DistributedHostProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Distributed

public protocol DistributedHostProtocol: Sendable {

    func start<Actor: DistributedActor>(
        actor: Actor,
        serviceName: String,
        serviceType: String,
        port: UInt16
    ) async throws(HostServerError) where Actor.ActorSystem == NetworkActorSystem

    func stop() async
}
