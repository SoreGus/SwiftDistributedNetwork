//
//  HostServerConfiguration.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation

public struct HostServerConfiguration: Sendable, Equatable {

    public let port: UInt16
    public let serviceName: String?
    public let serviceType: String
    public let maximumConnections: Int
    public let maximumMessageSize: Int

    public init(
        port: UInt16,
        serviceName: String? = nil,
        serviceType: String = "_application._tcp",
        maximumConnections: Int = 32,
        maximumMessageSize: Int = 1_048_576
    ) {
        self.port = port
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.maximumConnections = maximumConnections
        self.maximumMessageSize = maximumMessageSize
    }
}
