//
//  DistributedTransportProtocol.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public protocol DistributedTransportProtocol: Sendable {

    func send(
        message: DistributedMessage
    ) async throws(DistributedNetworkError)

    func receive() async throws(DistributedNetworkError) -> DistributedMessage
}
