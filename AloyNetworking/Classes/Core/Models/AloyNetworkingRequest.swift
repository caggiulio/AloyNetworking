//
//  AloyNetworkingRequest.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Describes a single HTTP request passed to `AloyNetworking.send(request:)`.
public struct AloyNetworkingRequest {
  // MARK: - Public properties

  /// Tuple of the raw URL string and optional query parameters.
  public typealias Path = (url: String, query: [URLQueryItem]?)
  /// Tuple of an `Encodable` body payload and its wire encoding strategy.
  public typealias Body = (data: Encodable, encoding: Encoding)

  /// HTTP verb.
  public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
  }

  /// URL scheme for this request.
  public enum Scheme: String {
    case http
    case https
  }

  /// How the body payload is serialised onto the wire.
  public enum Encoding {
    /// Serialises as `application/json`.
    case json
    /// Serialises as `application/x-www-form-urlencoded`.
    case urlEncoded
  }

  /// HTTP method for this request.
  public var method: HTTPMethod
  /// Destination URL and optional query items.
  public var path: Path
  /// HTTP headers. String values are forwarded as-is; non-String values are ignored.
  public var header: [String: Any]?
  /// Optional request body.
  public var body: Body?
  /// Overrides the URL scheme. Replaces whatever scheme is in `baseURL`.
  public var scheme: Scheme?

  // MARK: - Object lifecycle

  public init(method: HTTPMethod, path: Path, header: [String: Any]? = nil, body: Body? = nil, scheme: Scheme? = nil) {
    self.method = method
    self.path = path
    self.header = header
    self.body = body
    self.scheme = scheme
  }
}
