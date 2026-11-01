//
//  HostServerServiceProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

public protocol HostServerServiceProtocol: Sendable {

    func start(
        configuration: HostServerConfiguration
    ) async throws(HostServerError)

    func stop() async
}
