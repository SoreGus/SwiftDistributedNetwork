//
//  NetworkRemoteFailureTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation
import Testing
@testable import Contracts

private enum RemoteTestError: Error {
    case operationRejected
}

private distributed actor ThrowingActor {

    typealias ActorSystem = NetworkActorSystem

    distributed func execute() throws -> Int {
        throw RemoteTestError.operationRejected
    }

    distributed func executeVoid() throws {
        throw RemoteTestError.operationRejected
    }
}

struct NetworkRemoteFailureTests {

    @Test
    func remoteCallPreservesErrorInformation() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ThrowingActor(
            actorSystem: hostSystem
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try ThrowingActor.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        do {
            let _ = try await remoteActor.execute()

            Issue.record(
                "Expected a remote failure."
            )
        } catch let error as DistributedNetworkError {
            guard case .remoteFailure(let type, let description) = error else {
                Issue.record(
                    "Expected remoteFailure, received \(error)."
                )
                return
            }

            #expect(type == String(reflecting: RemoteTestError.self))
            #expect(description == "operationRejected")
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }

    @Test
    func remoteVoidCallPreservesErrorInformation() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ThrowingActor(
            actorSystem: hostSystem
        )

        let transport = MockDistributedTransport { message in
            await hostSystem.handle(
                message: message
            )
        }

        let clientSystem = NetworkActorSystem(
            transport: transport
        )

        let remoteActor = try ThrowingActor.resolve(
            id: hostActor.id,
            using: clientSystem
        )

        do {
            try await remoteActor.executeVoid()

            Issue.record(
                "Expected a remote failure."
            )
        } catch let error as DistributedNetworkError {
            guard case .remoteFailure(let type, let description) = error else {
                Issue.record(
                    "Expected remoteFailure, received \(error)."
                )
                return
            }

            #expect(type == String(reflecting: RemoteTestError.self))
            #expect(description == "operationRejected")
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }
}
