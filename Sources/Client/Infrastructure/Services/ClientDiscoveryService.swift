//
//  ClientDiscoveryService.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
@preconcurrency import Network

public actor ClientDiscoveryService: ClientDiscoveryServiceProtocol {

    private let queue: DispatchQueue
    private var browsers: [UUID: NWBrowser] = [:]

    public init() {
        self.queue = DispatchQueue(
            label: "SwiftDistributedNetwork.Client.Discovery"
        )
    }

    public func discover(
        serviceType: String = "_application._tcp"
    ) async -> AsyncStream<[ClientServerEndpoint]> {
        let (stream, continuation) = AsyncStream<[ClientServerEndpoint]>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        guard serviceType.hasPrefix("_"),
              serviceType.hasSuffix("._tcp") else {
            continuation.yield(
                []
            )

            continuation.finish()

            return stream
        }

        let identifier = UUID()

        let browser = NWBrowser(
            for: .bonjour(
                type: serviceType,
                domain: nil
            ),
            using: .tcp
        )

        browser.browseResultsChangedHandler = { results, changes in
            let endpoints = results.compactMap { result -> ClientServerEndpoint? in
                guard case .service(
                    let name,
                    let type,
                    let domain,
                    _
                ) = result.endpoint else {
                    return nil
                }

                return .bonjour(
                    name: name,
                    type: type,
                    domain: domain
                )
            }

            let uniqueEndpoints = Array(
                Set(endpoints)
            ).sorted { first, second in
                String(
                    describing: first
                ) < String(
                    describing: second
                )
            }

            continuation.yield(
                uniqueEndpoints
            )
        }

        browser.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled:
                continuation.finish()

            default:
                break
            }
        }

        continuation.onTermination = { [weak self] termination in
            Task {
                await self?.stopBrowser(
                    identifier: identifier
                )
            }
        }

        browsers[identifier] = browser

        continuation.yield(
            []
        )

        browser.start(
            queue: queue
        )

        return stream
    }

    private func stopBrowser(
        identifier: UUID
    ) {
        guard let browser = browsers.removeValue(
            forKey: identifier
        ) else {
            return
        }

        browser.cancel()
    }
}
