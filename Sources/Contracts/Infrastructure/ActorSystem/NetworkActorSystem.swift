//
//  NetworkActorSystem.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Distributed
import Foundation

public final class NetworkActorSystem: DistributedActorSystem, @unchecked Sendable {

    public typealias ActorID = DistributedActorIdentifier
    public typealias InvocationEncoder = NetworkInvocationEncoder
    public typealias InvocationDecoder = NetworkInvocationDecoder
    public typealias ResultHandler = NetworkInvocationResultHandler
    public typealias SerializationRequirement = Codable

    private typealias Dispatcher = @Sendable (
        String,
        NetworkInvocation
    ) async throws -> NetworkInvocationResult

    private let lock = NSLock()

    private var actors: [ActorID: Any] = [:]
    private var dispatchers: [ActorID: Dispatcher] = [:]
    private var publishedActors: [String: ActorID] = [:]

    private let requestService: (any NetworkRequestServiceProtocol)?
    private let registeredTypes: [String: Any.Type]

    public init(
        transport: (any DistributedTransportProtocol)? = nil,
        registeredTypes: [String: Any.Type] = [:]
    ) {
        self.requestService = transport.map {
            NetworkRequestService(
                transport: $0
            )
        }

        self.registeredTypes = registeredTypes
    }

    public func resolve<Act>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, ActorID == Act.ID {
        lock.withLock {
            actors[id] as? Act
        }
    }

    public func assignID<Act>(
        _ actorType: Act.Type
    ) -> ActorID where Act: DistributedActor, ActorID == Act.ID {
        ActorID()
    }

    public func actorReady<Act>(
        _ actor: Act
    ) where Act: DistributedActor, ActorID == Act.ID {
        let dispatcher: Dispatcher = { [self, actor] targetName, invocation in
            var decoder = InvocationDecoder(
                invocation: invocation,
                registeredTypes: registeredTypes,
                actorSystem: self
            )

            let handler = ResultHandler()

            try await executeDistributedTarget(
                on: actor,
                target: RemoteCallTarget(
                    targetName
                ),
                invocationDecoder: &decoder,
                handler: handler
            )

            guard let result = handler.result else {
                throw DistributedNetworkError.internalFailure
            }

            return result
        }

        lock.withLock {
            actors[actor.id] = actor
            dispatchers[actor.id] = dispatcher
        }
    }

    public func resignID(
        _ id: ActorID
    ) {
        lock.withLock {
            actors.removeValue(
                forKey: id
            )

            dispatchers.removeValue(
                forKey: id
            )

            publishedActors = publishedActors.filter { entry in
                entry.value != id
            }
        }
    }

    public func registerHostedActor<Act: DistributedActor>(
        actor: Act
    ) where Act.ActorSystem == NetworkActorSystem {
        let typeName = String(
            reflecting: Act.self
        )

        lock.withLock {
            publishedActors[typeName] = actor.id
        }
    }

    public func unregisterHostedActor(
        typeName: String,
        actorID: ActorID
    ) {
        lock.withLock {
            guard publishedActors[typeName] == actorID else {
                return
            }

            publishedActors.removeValue(
                forKey: typeName
            )
        }
    }

    public func resolveRemoteActorID<Act: DistributedActor>(
        actor: Act.Type
    ) async throws(DistributedNetworkError) -> ActorID where Act.ActorSystem == NetworkActorSystem {
        guard let requestService else {
            throw .connectionFailed
        }

        do {
            let typeName = String(
                reflecting: actor
            )

            let payload = try JSONEncoder().encode(
                typeName
            )

            let request = DistributedMessage(
                kind: .request,
                payload: payload
            )

            let response = try await requestService.call(
                message: request
            )

            try validate(
                response: response
            )

            return try JSONDecoder().decode(
                ActorID.self,
                from: response.payload
            )
        } catch let error as DistributedNetworkError {
            throw error
        } catch {
            throw .serializationFailed
        }
    }

    public func makeInvocationEncoder() -> InvocationEncoder {
        InvocationEncoder()
    }

    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res where Act: DistributedActor,
                                Err: Error,
                                Res: SerializationRequirement,
                                ActorID == Act.ID {
        let response = try await makeRemoteCall(
            actorID: actor.id,
            target: target,
            invocation: invocation.makeInvocation()
        )

        try validate(
            response: response
        )

        let decoder = JSONDecoder()
        decoder.userInfo[.actorSystemKey] = self

        return try decoder.decode(
            Res.self,
            from: response.payload
        )
    }

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws where Act: DistributedActor,
                         Err: Error,
                         ActorID == Act.ID {
        let response = try await makeRemoteCall(
            actorID: actor.id,
            target: target,
            invocation: invocation.makeInvocation()
        )

        try validate(
            response: response
        )

        guard response.payload.isEmpty else {
            throw DistributedNetworkError.invalidMessage
        }
    }

    private func makeRemoteCall(
        actorID: ActorID,
        target: RemoteCallTarget,
        invocation: NetworkInvocation
    ) async throws -> DistributedMessage {
        guard let requestService else {
            throw DistributedNetworkError.connectionFailed
        }

        let request = NetworkTargetInvocation(
            target: target.identifier,
            invocation: invocation
        )

        let payload = try JSONEncoder().encode(
            request
        )

        let message = DistributedMessage(
            kind: .request,
            actorID: actorID,
            payload: payload
        )

        return try await requestService.call(
            message: message
        )
    }

    private func validate(
        response: DistributedMessage
    ) throws {
        switch response.kind {
        case .response:
            return

        case .failure:
            let result = try JSONDecoder().decode(
                NetworkInvocationResult.self,
                from: response.payload
            )

            guard case .failure(let type, let description) = result else {
                throw DistributedNetworkError.invalidMessage
            }

            throw DistributedNetworkError.remoteFailure(
                type: type,
                description: description
            )

        case .request:
            throw DistributedNetworkError.invalidMessage
        }
    }

    public func handle(
        message: DistributedMessage
    ) async -> DistributedMessage {
        guard message.kind == .request else {
            return failureResponse(
                id: message.id,
                error: DistributedNetworkError.invalidMessage
            )
        }

        guard let actorID = message.actorID else {
            return handleActorLookup(
                message: message
            )
        }

        guard let dispatcher = lock.withLock({
            dispatchers[actorID]
        }) else {
            return failureResponse(
                id: message.id,
                error: DistributedNetworkError.actorNotFound
            )
        }

        do {
            let request = try JSONDecoder().decode(
                NetworkTargetInvocation.self,
                from: message.payload
            )

            let result = try await dispatcher(
                request.target,
                request.invocation
            )

            switch result {
            case .success(let payload):
                return DistributedMessage(
                    id: message.id,
                    kind: .response,
                    payload: payload
                )

            case .void:
                return DistributedMessage(
                    id: message.id,
                    kind: .response,
                    payload: Data()
                )

            case .failure:
                return failureResponse(
                    id: message.id,
                    result: result
                )
            }
        } catch {
            return failureResponse(
                id: message.id,
                error: error
            )
        }
    }

    private func handleActorLookup(
        message: DistributedMessage
    ) -> DistributedMessage {
        do {
            let typeName = try JSONDecoder().decode(
                String.self,
                from: message.payload
            )

            guard let actorID = lock.withLock({
                publishedActors[typeName]
            }) else {
                return failureResponse(
                    id: message.id,
                    error: DistributedNetworkError.actorNotFound
                )
            }

            let payload = try JSONEncoder().encode(
                actorID
            )

            return DistributedMessage(
                id: message.id,
                kind: .response,
                payload: payload
            )
        } catch {
            return failureResponse(
                id: message.id,
                error: error
            )
        }
    }

    private func failureResponse(
        id: UUID,
        error: any Error
    ) -> DistributedMessage {
        failureResponse(
            id: id,
            result: .failure(
                type: String(
                    reflecting: type(of: error as Any)
                ),
                description: String(
                    describing: error
                )
            )
        )
    }

    private func failureResponse(
        id: UUID,
        result: NetworkInvocationResult
    ) -> DistributedMessage {
        let payload = (try? JSONEncoder().encode(
            result
        )) ?? Data()

        return DistributedMessage(
            id: id,
            kind: .failure,
            payload: payload
        )
    }

    public func invokeHandlerOnReturn(
        handler: ResultHandler,
        resultBuffer: UnsafeRawPointer,
        metatype: any Any.Type
    ) async throws {
        func deliver<T>(
            _ type: T.Type
        ) async throws {
            let value = resultBuffer.load(
                as: T.self
            )

            guard let codable = value as? any Codable else {
                throw DistributedNetworkError.serializationFailed
            }

            try await handler.onReturn(
                value: codable
            )
        }

        try await _openExistential(
            metatype,
            do: deliver
        )
    }
}
