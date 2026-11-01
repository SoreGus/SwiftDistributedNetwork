//
//  NetworkInvocation.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public struct NetworkInvocation: Codable, Sendable, Equatable {

    public let genericSubstitutions: [String]
    public let arguments: [Data]
    public let returnType: String?
    public let errorType: String?

    public init(
        genericSubstitutions: [String],
        arguments: [Data],
        returnType: String?,
        errorType: String?
    ) {
        self.genericSubstitutions = genericSubstitutions
        self.arguments = arguments
        self.returnType = returnType
        self.errorType = errorType
    }
}
