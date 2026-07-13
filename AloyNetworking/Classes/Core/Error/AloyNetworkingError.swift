//
//  AloyNetworkingError.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Enum for errors
public enum AloyNetworkingError: Error {
  case invalidUrl
  case invalidHTTPResponse
  case decodingFailed(error: Error)
  case other(error: Error)
  case underlying(statusCode: Int, data: Data?)
}
