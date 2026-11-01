//
//  DistributedActorIdentifier.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public struct DistributedActorIdentifier: Hashable, Codable, Sendable {

    public let value: UUID

    public init(
        value: UUID = UUID()
    ) {
        self.value = value
    }
}
