//
//  AloyInterceptorProtocol.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Allows mutation of a request before it is sent.
public protocol RequestAdapter {
    /// Returns a (possibly modified) copy of `request`.
    func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest
}

/// Decides whether a failed request should be retried.
public protocol RetryAdapter {
    /// Called after a request fails. Return `.retry` to re-send, `.doNotRetry` to propagate the error.
    func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult
}

/// Combines request adaptation and retry logic. Conform to this to plug custom auth, logging, or retry policies into `AloyNetworking`.
public protocol AloyInterceptorProtocol: RequestAdapter, RetryAdapter {}

public extension AloyInterceptorProtocol {
    func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest {
        return request
    }

    func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult {
        return .doNotRetry
    }
}

/// The outcome of a retry decision.
public enum RetryResult {
    /// Re-send the original request.
    case retry
    /// Propagate the error without retrying.
    case doNotRetry
}
