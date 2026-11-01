//
//  ClientTestHost.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Foundation
import Host

enum ClientTestHost {

    static let serviceType = "_application._tcp"

    static func run<ResultValue: Sendable>(
        actorSystem: NetworkActorSystem,
        serviceName: String = "SwiftDistributedNetworkClientTests",
        operation: @Sendable (UInt16) async throws -> ResultValue
    ) async throws -> ResultValue {
        let service = HostServerService(
            actorSystem: actorSystem
        )

        var selectedPort: UInt16?

        for _ in 0..<20 {
            let port = UInt16.random(
                in: 30_000...60_000
            )

            do {
                try await service.start(
                    configuration: HostServerConfiguration(
                        port: port,
                        serviceName: serviceName,
                        serviceType: serviceType
                    )
                )

                selectedPort = port
                break
            } catch HostServerError.startFailed {
                continue
            }
        }

        guard let selectedPort else {
            throw HostServerError.startFailed(
                "Could not start a test server."
            )
        }

        do {
            let result = try await operation(
                selectedPort
            )

            await service.stop()

            return result
        } catch {
            await service.stop()
            throw error
        }
    }
}
