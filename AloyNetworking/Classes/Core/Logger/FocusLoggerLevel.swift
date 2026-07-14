//
//  AloyNetworkingLoggerLogLevel.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// Controls how much network activity `AloyNetworking` prints to the console.
public enum FocusLoggerLevel {
  /// Logging disabled.
  case none
  /// Prints full request and response details including body.
  case debug
  /// Prints status codes only, without body content.
  case release
}
