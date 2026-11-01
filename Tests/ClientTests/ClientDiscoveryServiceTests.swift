//
//  ClientDiscoveryServiceTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//


import Client
import Contracts
import Foundation
import Testing

@Suite(.serialized)
struct ClientDiscoveryServiceTests {

    @Test
    func discoveryRejectsInvalidServiceType() async {
        let service = ClientDiscoveryService()

        let stream = await service.discover(
            serviceType: "invalid"
        )

        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        let second = await iterator.next()

        #expect(first == [])
        #expect(second == nil)
    }

    @Test
    func discoveryFindsHostAndExecutesRemoteMethod() async throws {
        let hostSystem = NetworkActorSystem()

        let hostActor = ClientTestCounter(
            actorSystem: hostSystem
        )

        let serviceName = "CCClient-\(UUID().uuidString.prefix(8))"

        try await ClientTestHost.run(
            actorSystem: hostSystem,
            serviceName: serviceName
        ) { port in
            let discoveryService = ClientDiscoveryService()

            let stream = await discoveryService.discover(
                serviceType: ClientTestHost.serviceType
            )

            let discoveryTask = Task {
                () -> ClientServerEndpoint? in

                for await endpoints in stream {
                    if let endpoint = endpoints.first(where: { endpoint in
                        guard case .bonjour(
                            let name,
                            let type,
                            _
                        ) = endpoint else {
                            return false
                        }

                        return name == serviceName
                            && type == ClientTestHost.serviceType
                    }) {
                        return endpoint
                    }
                }

                return nil
            }

            let timeoutTask = Task {
                try? await Task.sleep(
                    for: .seconds(10)
                )

                discoveryTask.cancel()
            }

            let discoveredEndpoint = await discoveryTask.value

            timeoutTask.cancel()

            guard let discoveredEndpoint else {
                Issue.record(
                    "The Host was not discovered through Bonjour."
                )
                return
            }

            let connectionService = ClientConnectionService()

            let clientSystem = try await connectionService.connect(
                endpoint: discoveredEndpoint
            )

            let remoteActor = try ClientTestCounter.resolve(
                id: hostActor.id,
                using: clientSystem
            )

            let value = try await remoteActor.increment(
                amount: 7
            )

            #expect(value == 7)

            await connectionService.disconnect()
        }
    }

    @Test
    func endpointsSupportEquality() {
        let first = ClientServerEndpoint.bonjour(
            name: "SwiftDistributedNetwork",
            type: "_application._tcp",
            domain: "local."
        )

        let second = ClientServerEndpoint.bonjour(
            name: "SwiftDistributedNetwork",
            type: "_application._tcp",
            domain: "local."
        )

        let third = ClientServerEndpoint.host(
            name: "127.0.0.1",
            port: 8080
        )

        #expect(first == second)
        #expect(first != third)
    }
}
