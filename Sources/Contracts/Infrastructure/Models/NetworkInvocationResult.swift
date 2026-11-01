//
//  NetworkInvocationResult.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public enum NetworkInvocationResult: Codable, Sendable, Equatable {

    case success(Data)
    case void
    case failure(type: String, description: String)
}
