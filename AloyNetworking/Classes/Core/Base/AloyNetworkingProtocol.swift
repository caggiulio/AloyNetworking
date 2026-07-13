//
//  AloyNetworkingProtocol.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

public protocol AloyNetworkingProtocol {
  // MARK: - iOS > 15 Protocols

  @available(macOS 12.0, iOS 15.0, *)
  /// This is the func to use to make an HTTP call in async/await version.
  /// - Parameter request: The `AloyNetworkingRequest` object with HTTP information request.
  /// - Returns `SuccessResponse` using `async await` pattern. `SuccessResponse` is a Decodable to decode in HTTP response.
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest) async throws -> SuccessResponse

  /// This is the func to use to make an HTTP multipart call in async/await version.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  /// - Returns `SuccessResponse` using `async await` pattern. `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(macOS 12.0, iOS 15.0, *)
  func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> SuccessResponse
}
