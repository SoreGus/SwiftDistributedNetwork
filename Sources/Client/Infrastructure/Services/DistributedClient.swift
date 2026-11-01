//
//  DistributedClient.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Distributed
import Foundation

public actor DistributedClient: DistributedClientProtocol {

    private let connectionService: ClientConnectionService

    private var sessionID = UUID()

    public init() {
        self.connectionService = ClientConnectionService()
    }

    public func connect<Actor: DistributedActor>(
        actor: Actor.Type,
        serviceName: String,
        serviceType: String
    ) async throws(ClientConnectionError) -> Actor where Actor.ActorSystem == NetworkActorSystem {
        guard !serviceName.isEmpty,
              serviceType.hasPrefix("_"),
              serviceType.hasSuffix("._tcp") else {
            throw .invalidEndpoint
        }

        let identifier = UUID()
        sessionID = identifier

        let endpoint = ClientServerEndpoint.bonjour(
            name: serviceName,
            type: serviceType,
            domain: "local."
        )

        do {
            let actorSystem = try await connectionService.connect(
                endpoint: endpoint
            )

            guard sessionID == identifier,
                  !Task.isCancelled else {
                throw ClientConnectionError.cancelled
            }

            let actorID: DistributedActorIdentifier

            do {
                actorID = try await actorSystem.resolveRemoteActorID(
                    actor: actor
                )
            } catch {
                throw ClientConnectionError.connectionFailed
            }

            guard sessionID == identifier,
                  !Task.isCancelled else {
                throw ClientConnectionError.cancelled
            }

            do {
                return try Actor.resolve(
                    id: actorID,
                    using: actorSystem
                )
            } catch {
                throw ClientConnectionError.connectionFailed
            }
        } catch {
            if sessionID == identifier {
                await connectionService.disconnect()
            }

            if let connectionError = error as? ClientConnectionError {
                throw connectionError
            }

            throw .connectionFailed
        }
    }

    public func disconnect() async {
        sessionID = UUID()

        await connectionService.disconnect()
    }
}
