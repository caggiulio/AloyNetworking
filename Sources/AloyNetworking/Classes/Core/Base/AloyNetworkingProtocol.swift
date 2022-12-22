//
//  AloyNetworkingProtocol.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Combine
import Foundation

public protocol AloyNetworkingProtocol {
  // MARK: - iOS > 15 Protocols

  @available(iOS 15.0, *)
  /// This is the func to use to make an HTTP call in Combine version.
  /// - Parameter request: The `AloyNetworkingRequest` object with HTTP information request.
  /// - Returns `SuccessResponse` using `async await` pattern. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest) async throws -> SuccessResponse

  /// This is the func to use to make an HTTP multipart call in Combine version.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  /// - Returns `SuccessResponse` using `async await` pattern. `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> SuccessResponse

  // MARK: - iOS > 13 Protocols

  /// This is the func to use to make an HTTP call in Combine version.
  /// - Parameter request: The `AloyNetworkingRequest` object with HTTP information request.
  /// - Returns  AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(iOS 13.0, *)
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest) -> AnyPublisher<SuccessResponse, Error>

  /// This is the func to use to make an HTTP call in Combine version using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  /// - Returns: AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(iOS 13.0, *)
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, decoder: JSONDecoder) -> AnyPublisher<SuccessResponse, Error>

  /// This is the func to use to make an HTTP multipart call in Combine version.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  /// - Returns: AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(iOS 13.0, *)
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) -> AnyPublisher<SuccessResponse, Error>

  /// This is the func to use to make an HTTP multipart call in Combine version using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  /// - Returns: AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(iOS 13.0, *)
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String, decoder: JSONDecoder) -> AnyPublisher<SuccessResponse, Error>

  // MARK: - iOS < 13 Protocols

  /// This is the func to use to make an HTTP call.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, completion: ((Result<SuccessResponse, Error>) -> Void)?)

  /// This is the func to use to make an HTTP call using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, decoder: JSONDecoder, completion: ((Result<SuccessResponse, Error>) -> Void)?)

  /// This is the func to use to make an HTTP multipart call.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String, completion: ((Result<SuccessResponse, Error>) -> Void)?)

  /// This is the func to use to make an HTTP multipart call using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String, decoder: JSONDecoder, completion: ((Result<SuccessResponse, Error>) -> Void)?)
}
