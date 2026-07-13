//
//  AloyNetworking.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

#if canImport(Combine)
import Combine
#endif

// MARK: - AloyNetworking

/// Public class used to build an object that will deal with HTTP calls. It's builded with the `baseURL` and the `AloyInterceptorProtocol` passed on init.
public class AloyNetworking: NSObject, AloyNetworkingProtocol {
  // MARK: - Public methods

  /// Prints network calls in the console.
  /// Values available are .none and .debug(default).
  /// - `.none`: The logger is off.
  /// - `.debug`: All the network informations(request and response) are printed.
  public var logLevel: FocusLoggerLevel {
    get { return logger.logLevel }
    set { logger.logLevel = newValue }
  }

  // MARK: - Business logic properties

  private let baseURL: String

  /// The interceptor is used to adapt `URL` request and retry mechanism
  private var interceptor: AloyInterceptorProtocol?

  /// The `HTTPTransport`
  private let transport: HTTPTransport

  /// Instance of `FocusLogger`
  private var logger = FocusLogger()

  /// The init of a `AloyNetworking` instance.
  /// - Parameter baseURL: The host baseURL for this instance of `AloyNetworking`
  /// - Parameter transport: The transport layer used to execute HTTP requests
  /// - Parameter interceptor: The interceptor is used to adapt `URL` request and retry mechanism
  public init(baseURL: String, transport: HTTPTransport, interceptor: AloyInterceptorProtocol? = nil) {
    self.baseURL = baseURL
    self.transport = transport
    self.interceptor = interceptor
  }

  // MARK: - iOS > 15 Protocols

  @available(macOS 12.0, iOS 15.0, *)
  public func send<SuccessResponse>(request: AloyNetworkingRequest) async throws -> SuccessResponse where SuccessResponse: Decodable {
    var adaptedRequest = interceptor?.adapt(request) ?? request
    adaptedRequest.path = (url: baseURL + adaptedRequest.path.url, query: adaptedRequest.path.query)
    logger.logRequest(adaptedRequest)
    let (data, statusCode) = try await transport.execute(adaptedRequest)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)

    return try await handleResponse(data: data, statusCode: statusCode, originalRequest: adaptedRequest)
  }

  @available(macOS 12.0, iOS 15.0, *)
  public func send<SuccessResponse>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> SuccessResponse where SuccessResponse: Decodable {
    var adaptedRequest = interceptor?.adapt(request) ?? request
    adaptedRequest.path = (url: baseURL + adaptedRequest.path.url, query: adaptedRequest.path.query)
    let multipartRequest = buildMultipartRequest(from: adaptedRequest, medias: medias, boundary: boundary)
    let (data, statusCode) = try await transport.execute(multipartRequest)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)

    return try await handleResponse(data: data, statusCode: statusCode, originalRequest: multipartRequest)
  }
}

// MARK: - Private methods

private extension AloyNetworking {
  func buildMultipartRequest(from request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) -> AloyNetworkingRequest {
    let body = makeMultipartBody(request: request, medias: medias, boundary: boundary)
    // Wrap raw multipart data as a custom body via a RawDataEncodable shim
    var headers = request.header ?? [:]
    headers["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
    return AloyNetworkingRequest(
      method: request.method,
      path: request.path,
      header: headers,
      body: (data: RawDataBody(data: body), encoding: .json)
    )
  }

  /// This method is used to build the HTTP multipart Body
  func makeMultipartBody(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia]?, boundary: String) -> Data {
    func append(_ string: String, to data: inout Data) {
      guard let dataToAppend = string.data(using: .utf8) else {
        assertionFailure("Could not append data!")
        return
      }
      data.append(dataToAppend)
    }

    let lineBreak = "\r\n"
    var body = Data()

    let params = request.body?.data.dictionary
    params?.compactMap { $0 }
      .forEach { param in
        let valueString = String(describing: param.value)
        append("--\(boundary + lineBreak)", to: &body)
        append("Content-Disposition: form-data; name=\"\(param.key)\"\(lineBreak + lineBreak)", to: &body)
        append("\(valueString + lineBreak)", to: &body)
      }

    medias?.compactMap { $0 }
      .forEach { media in
        append("--\(boundary + lineBreak)", to: &body)
        append("Content-Disposition: form-data; name=\"\(media.key)\"; filename=\"\(media.filename)\"\(lineBreak)", to: &body)
        append("Content-Type: \(media.mimeType + lineBreak + lineBreak)", to: &body)
        body.append(media.data)
        append(lineBreak, to: &body)
      }

    append("--\(boundary)--\(lineBreak)", to: &body)

    return body
  }
}

// MARK: - Functions used with async await

@available(macOS 12.0, iOS 15.0, *)
private extension AloyNetworking {
  /// This func is the final step to make an HTTP call in async await version using the `data(for: URLRequest)`func.
  func handleResponse<T: Decodable>(data: Data, statusCode: Int, originalRequest: AloyNetworkingRequest) async throws -> T {
    switch statusCode {
    case 200...299:
      do {
        return try JSONDecoder().decode(T.self, from: data)
      } catch {
        throw AloyNetworkingError.decodingFailed(error: error)
      }
      
    default:
      let error = AloyNetworkingError.underlying(statusCode: statusCode, data: data)
      logger.logResponse(statusCode: statusCode, data: data, error: error)
      
      return try await shouldRetry(request: originalRequest, error: error)
    }
  }

  /// Func used to understand if the system should retry the request in async await version
  func shouldRetry<T: Decodable>(request: AloyNetworkingRequest, error: Error) async throws -> T {
    guard let interceptor else { throw error }
    
    let result = try await interceptor.retry(request, dueTo: error)
    switch result {
    case .retry:
      return try await send(request: request)
      
    case .doNotRetry:
      throw error
    }
  }
}

/// Shim to pass raw Data through the Encodable body slot
private struct RawDataBody: Encodable {
    let data: Data
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}
