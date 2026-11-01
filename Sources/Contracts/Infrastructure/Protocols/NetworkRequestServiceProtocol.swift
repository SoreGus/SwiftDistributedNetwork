//
//  NetworkRequestServiceProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

public protocol NetworkRequestServiceProtocol: Sendable {

    func call(
        message: DistributedMessage
    ) async throws(DistributedNetworkError) -> DistributedMessage
}
