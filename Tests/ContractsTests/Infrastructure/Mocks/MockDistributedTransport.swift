//
//  MockDistributedTransport.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
@testable import Contracts

actor MockDistributedTransport: DistributedTransportProtocol {

    typealias Responder = @Sendable (
        DistributedMessage
    ) async -> DistributedMessage

    private let responder: Responder
    private let sendError: DistributedNetworkError?
    private let receiveError: DistributedNetworkError?

    private var messages: [DistributedMessage] = []
    private var pendingMessage: DistributedMessage?

    init(
        sendError: DistributedNetworkError? = nil,
        receiveError: DistributedNetworkError? = nil,
        responder: @escaping Responder
    ) {
        self.sendError = sendError
        self.receiveError = receiveError
        self.responder = responder
    }

    func send(
        message: DistributedMessage
    ) async throws(DistributedNetworkError) {
        if let sendError {
            throw sendError
        }

        messages.append(
            message
        )

        pendingMessage = message
    }

    func receive() async throws(DistributedNetworkError) -> DistributedMessage {
        if let receiveError {
            throw receiveError
        }

        guard let pendingMessage else {
            throw DistributedNetworkError.invalidMessage
        }

        self.pendingMessage = nil

        return await responder(
            pendingMessage
        )
    }

    func sentMessages() -> [DistributedMessage] {
        messages
    }
}
