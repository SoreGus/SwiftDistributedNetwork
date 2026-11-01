//
//  DistributedMessage.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public struct DistributedMessage: Codable, Sendable, Equatable {

    public enum Kind: String, Codable, Sendable {
        case request
        case response
        case failure
    }

    public let id: UUID
    public let kind: Kind
    public let actorID: DistributedActorIdentifier?
    public let payload: Data

    public init(
        id: UUID = UUID(),
        kind: Kind,
        actorID: DistributedActorIdentifier? = nil,
        payload: Data
    ) {
        self.id = id
        self.kind = kind
        self.actorID = actorID
        self.payload = payload
    }
}
