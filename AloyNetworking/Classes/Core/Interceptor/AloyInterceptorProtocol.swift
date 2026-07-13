//
//  AloyInterceptorProtocol.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

public protocol RequestAdapter {
    func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest
}

public protocol RetryAdapter {
    func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult
}

public protocol AloyInterceptorProtocol: RequestAdapter, RetryAdapter {}

public extension AloyInterceptorProtocol {
    func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest {
        return request
    }

    func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult {
        return .doNotRetry
    }
}

public enum RetryResult {
    case retry
    case doNotRetry
}
