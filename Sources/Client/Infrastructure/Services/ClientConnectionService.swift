//
//  ClientConnectionService.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Contracts
import Foundation
@preconcurrency import Network

public actor ClientConnectionService: ClientConnectionServiceProtocol {

    private var transport: ClientTCPTransport?
    private var sessionID = UUID()

    public init() {}

    public func connect(
        endpoint: ClientServerEndpoint
    ) async throws(ClientConnectionError) -> NetworkActorSystem {
        let networkEndpoint: NWEndpoint

        switch endpoint {
        case .bonjour(let name, let type, let domain):
            guard !name.isEmpty,
                  !type.isEmpty,
                  !domain.isEmpty else {
                throw .invalidEndpoint
            }

            networkEndpoint = .service(
                name: name,
                type: type,
                domain: domain,
                interface: nil
            )

        case .host(let name, let port):
            guard !name.isEmpty,
                  port != 0,
                  let networkPort = NWEndpoint.Port(
                      rawValue: port
                  ) else {
                throw .invalidEndpoint
            }

            networkEndpoint = .hostPort(
                host: NWEndpoint.Host(
                    name
                ),
                port: networkPort
            )
        }

        let identifier = UUID()
        sessionID = identifier

        let previousTransport = transport
        transport = nil

        await previousTransport?.close()

        guard sessionID == identifier,
              !Task.isCancelled else {
            throw .cancelled
        }

        let newTransport = ClientTCPTransport(
            endpoint: networkEndpoint
        )

        transport = newTransport

        do {
            try await newTransport.connect()

            guard sessionID == identifier,
                  !Task.isCancelled else {
                await newTransport.close()
                throw ClientConnectionError.cancelled
            }

            return NetworkActorSystem(
                transport: newTransport
            )
        } catch {
            await newTransport.close()

            guard sessionID == identifier else {
                throw .cancelled
            }

            transport = nil

            if let connectionError = error as? ClientConnectionError {
                throw connectionError
            }

            throw .connectionFailed
        }
    }

    public func disconnect() async {
        sessionID = UUID()

        let activeTransport = transport
        transport = nil

        await activeTransport?.close()
    }
}
