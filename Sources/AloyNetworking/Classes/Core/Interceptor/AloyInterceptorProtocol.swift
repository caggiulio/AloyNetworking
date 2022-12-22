//
//  AloyInterceptorProtocol.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Combine
import Foundation

// MARK: - RequestAdapter

public protocol RequestAdapter {
  /// Inspects and adapts the specified `URLRequest` in some manner and return the request.
  /// - Parameter urlRequest: The final request to adapt
  /// - Returns: The final URLRequest to send
  func adapt(_ urlRequest: URLRequest) -> URLRequest
}

// MARK: - RetryAdapter

public protocol RetryAdapter {
  @available(iOS 15.0.0, *)
  func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error?) async throws -> RetryResult

  // MARK: - iOS > 15 Protocols

  /// This func must be used to execute code before retry a failed request in `async-await` version. After the code, you must return a RetryResult
  ///
  /// This is an example of Future usage
  ///
  ///     do {
  ///       let _ = try await webService.sendRequest(request: request)
  ///       return .retry
  ///     } catch {
  ///       return .doNotRetry
  ///     }
  ///
  /// - Parameter request: The request failes
  /// - Parameter session: The session that generated the failed request
  /// - Parameter error: The error generated by the request failed
  /// - Returns: The `RetryResult` to determinate if the system must retry the failed request.

  @available(iOS 13.0, *)
  func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error?) -> AnyPublisher<RetryResult, Error>

  // MARK: - iOS > 13 Protocols

  /// This func must be used to execute code before retry a failed request in Combine version. After the code, you must return a Future with RetryResult
  ///
  /// This is an example of Future usage
  ///
  ///     return Future { promise in
  ///         webService.sendRequest(request: request)
  ///             .sink { completion in
  ///               promise(.success(.doNotRetry))
  ///           } receiveValue: { results in
  ///               promise(.success(.retry))
  ///           }
  ///      }.eraseToAnyPublisher()
  ///
  /// - Parameter request: The request failes
  /// - Parameter session: The session that generated the failed request
  /// - Parameter error: The error generated by the request failed
  /// - Returns: AnyPublisher with `RetryResult` to determinate if the system must retry the failed request.

  func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error?, completion: @escaping (RetryResult) -> Void)

  // MARK: - iOS < 13 Protocols

  /// This func must be used to execute code before retry a failed request. After the code, you must launch a closure with a RetryResult enum
  ///
  /// This is an example:
  ///
  ///      webService.sendRequest(request: request) { completionResult in
  ///           switch completionResult {
  ///                case .success(_):
  ///                     completion(.retry)
  ///                case .failure(_):
  ///                     completion(.doNotRetry)
  ///           }
  ///      }
  ///
  /// - Parameter request: The request failes
  /// - Parameter session: The session that generated the failed request
  /// - Parameter error: The error generated by the request failed
  /// - Parameter completion: Completion closure to be executed when a retry decision has been determined.
}

// MARK: - AloyInterceptorProtocol

public protocol AloyInterceptorProtocol: RequestAdapter, RetryAdapter {}

public extension AloyInterceptorProtocol {
  func adapt(_ urlRequest: URLRequest) -> URLRequest {
    return urlRequest
  }

  @available(iOS 13.0, *)
  func retry(_: URLRequest, for _: URLSession, dueTo _: Error?) -> AnyPublisher<RetryResult, Error> {
    return Future { promise in
      promise(.success(.doNotRetry))
    }.eraseToAnyPublisher()
  }

  func retry(_: URLRequest, for _: URLSession, dueTo _: Error?, completion: @escaping (RetryResult) -> Void) {
    completion(.doNotRetry)
  }
}

// MARK: - RetryResult

/// Outcome of determination whether retry is necessary.
public enum RetryResult {
  /// Retry should be attempted immediately.
  case retry
  /// Do not retry.
  case doNotRetry
}
