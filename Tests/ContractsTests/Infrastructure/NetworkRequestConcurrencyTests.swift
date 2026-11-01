//
//  NetworkRequestConcurrencyTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
import Testing
@testable import Contracts

struct NetworkRequestConcurrencyTests {

    @Test
    func concurrentRequestsReceiveMatchingResponses() async throws {
        let transport = MockDistributedTransport { request in
            await Task.yield()

            return DistributedMessage(
                id: request.id,
                kind: .response,
                payload: request.payload
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let requestCount = 20

        let results = try await withThrowingTaskGroup(
            of: Bool.self,
            returning: [Bool].self
        ) { group in
            for index in 0..<requestCount {
                group.addTask {
                    let payload = Data(
                        [UInt8(index)]
                    )

                    let request = DistributedMessage(
                        kind: .request,
                        actorID: DistributedActorIdentifier(),
                        payload: payload
                    )

                    let response = try await service.call(
                        message: request
                    )

                    return response.id == request.id
                        && response.kind == .response
                        && response.payload == request.payload
                }
            }

            var results: [Bool] = []

            for try await result in group {
                results.append(
                    result
                )
            }

            return results
        }

        #expect(results.count == requestCount)
        #expect(results.allSatisfy { $0 })

        let messages = await transport.sentMessages()

        #expect(messages.count == requestCount)
        #expect(Set(messages.map(\.id)).count == requestCount)
    }
}
