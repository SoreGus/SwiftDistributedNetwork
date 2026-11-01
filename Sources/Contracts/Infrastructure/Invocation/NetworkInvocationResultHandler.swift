//
//  NetworkInvocationResultHandler.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation
import Synchronization

public final class NetworkInvocationResultHandler: DistributedTargetInvocationResultHandler, Sendable {

    public typealias SerializationRequirement = Codable

    private let storage = Mutex<NetworkInvocationResult?>(
        nil
    )

    public init() {}

    public var result: NetworkInvocationResult? {
        storage.withLock { result in
            result
        }
    }

    public func onReturn<Success>(
        value: Success
    ) async throws where Success: SerializationRequirement {
        let data = try JSONEncoder().encode(
            value
        )

        try store(
            result: .success(data)
        )
    }

    public func onReturnVoid() async throws {
        try store(
            result: .void
        )
    }

    public func onThrow<Err>(
        error: Err
    ) async throws where Err: Error {
        try store(
            result: .failure(
                type: String(
                    reflecting: type(of: error as Any)
                ),
                description: String(
                    describing: error
                )
            )
        )
    }

    private func store(
        result: NetworkInvocationResult
    ) throws {
        try storage.withLock { storedResult in
            guard storedResult == nil else {
                throw DistributedNetworkError.invalidMessage
            }

            storedResult = result
        }
    }
}
