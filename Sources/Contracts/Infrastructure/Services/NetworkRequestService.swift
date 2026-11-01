
//
//  NetworkRequestService.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

actor NetworkRequestService: NetworkRequestServiceProtocol {

    private let transport: any DistributedTransportProtocol

    private var isExecuting = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(
        transport: any DistributedTransportProtocol
    ) {
        self.transport = transport
    }

    func call(
        message: DistributedMessage
    ) async throws(DistributedNetworkError) -> DistributedMessage {
        await acquire()

        defer {
            release()
        }

        do {
            try await transport.send(
                message: message
            )

            let response = try await transport.receive()

            guard response.id == message.id,
                  response.kind != .request else {
                throw DistributedNetworkError.invalidMessage
            }

            return response
        } catch let error as DistributedNetworkError {
            throw error
        } catch {
            throw DistributedNetworkError.internalFailure
        }
    }

    private func acquire() async {
        guard isExecuting else {
            isExecuting = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(
                continuation
            )
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isExecuting = false
            return
        }

        let continuation = waiters.removeFirst()

        continuation.resume()
    }
}
