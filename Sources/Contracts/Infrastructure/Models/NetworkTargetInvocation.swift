//
//  NetworkTargetInvocation.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

struct NetworkTargetInvocation: Codable, Sendable {

    let target: String
    let invocation: NetworkInvocation
}
