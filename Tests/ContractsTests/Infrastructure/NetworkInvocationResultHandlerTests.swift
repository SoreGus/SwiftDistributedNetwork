//
//  NetworkInvocationResultHandlerTests.swift
//  SwiftDistributedNetwork
//
//  Created by Gustavo Soré on 01/11/26.
//

import Foundation
import Testing
@testable import Contracts

struct NetworkInvocationResultHandlerTests {

    private enum TestError: Error {
        case failed
    }

    @Test
    func handlerRecordsReturnValue() async throws {
        let handler = NetworkInvocationResultHandler()

        try await handler.onReturn(
            value: 42
        )

        let result = handler.result

        guard case .success(let data) = result else {
            Issue.record(
                "Expected a successful result."
            )
            return
        }

        let value = try JSONDecoder().decode(
            Int.self,
            from: data
        )

        #expect(value == 42)
    }

    @Test
    func handlerRecordsVoidReturn() async throws {
        let handler = NetworkInvocationResultHandler()

        try await handler.onReturnVoid()

        let result = handler.result

        #expect(result == .void)
    }

    @Test
    func handlerRecordsThrownError() async throws {
        let handler = NetworkInvocationResultHandler()

        try await handler.onThrow(
            error: TestError.failed
        )

        let result = handler.result

        guard case .failure(let type, let description) = result else {
            Issue.record(
                "Expected a failure result."
            )
            return
        }

        #expect(type.contains("TestError"))
        #expect(description == "failed")
    }

    @Test
    func handlerRejectsMultipleResults() async throws {
        let handler = NetworkInvocationResultHandler()

        try await handler.onReturn(
            value: 42
        )

        do {
            try await handler.onReturnVoid()

            Issue.record(
                "Expected the second result to be rejected."
            )
        } catch let error as DistributedNetworkError {
            #expect(error == .invalidMessage)
        } catch {
            Issue.record(
                "Unexpected error: \(error)"
            )
        }
    }
}
