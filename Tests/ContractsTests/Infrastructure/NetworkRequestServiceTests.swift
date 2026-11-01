//
//  NetworkRequestServiceTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
import Testing
@testable import Contracts

struct NetworkRequestServiceTests {

    @Test
    func serviceSendsRequestAndReceivesResponse() async throws {
        let transport = MockDistributedTransport { request in
            DistributedMessage(
                id: request.id,
                kind: .response,
                payload: Data(
                    [1, 2, 3]
                )
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let request = DistributedMessage(
            kind: .request,
            actorID: DistributedActorIdentifier(),
            payload: Data(
                [4, 5, 6]
            )
        )

        let response = try await service.call(
            message: request
        )

        let sentMessages = await transport.sentMessages()

        #expect(sentMessages == [request])
        #expect(response.id == request.id)
        #expect(response.kind == .response)
        #expect(response.payload == Data([1, 2, 3]))
    }

    @Test
    func serviceRejectsMismatchedResponseIdentifier() async {
        let transport = MockDistributedTransport { request in
            DistributedMessage(
                id: UUID(),
                kind: .response,
                payload: request.payload
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let request = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        await #expect(throws: DistributedNetworkError.invalidMessage) {
            try await service.call(
                message: request
            )
        }
    }

    @Test
    func serviceRejectsRequestAsResponse() async {
        let transport = MockDistributedTransport { request in
            DistributedMessage(
                id: request.id,
                kind: .request,
                payload: Data()
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let request = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        await #expect(throws: DistributedNetworkError.invalidMessage) {
            try await service.call(
                message: request
            )
        }
    }

    @Test
    func servicePropagatesSendFailure() async {
        let transport = MockDistributedTransport(
            sendError: .connectionFailed
        ) { request in
            DistributedMessage(
                id: request.id,
                kind: .response,
                payload: Data()
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let request = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        await #expect(throws: DistributedNetworkError.connectionFailed) {
            try await service.call(
                message: request
            )
        }
    }

    @Test
    func servicePropagatesReceiveFailure() async {
        let transport = MockDistributedTransport(
            receiveError: .connectionClosed
        ) { request in
            DistributedMessage(
                id: request.id,
                kind: .response,
                payload: Data()
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let request = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        await #expect(throws: DistributedNetworkError.connectionClosed) {
            try await service.call(
                message: request
            )
        }
    }

    @Test
    func serviceAcceptsRemoteFailureResponse() async throws {
        let transport = MockDistributedTransport { request in
            DistributedMessage(
                id: request.id,
                kind: .failure,
                payload: Data()
            )
        }

        let service = NetworkRequestService(
            transport: transport
        )

        let request = DistributedMessage(
            kind: .request,
            payload: Data()
        )

        let response = try await service.call(
            message: request
        )

        #expect(response.id == request.id)
        #expect(response.kind == .failure)
    }
}
