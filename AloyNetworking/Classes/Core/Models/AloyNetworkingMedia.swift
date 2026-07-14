//
//  AloyNetworkingMedia.swift
//  AloyNetworking
//
//  Copyright © 2022 Nunzio Giulio Caggegi All rights reserved.
//

import Foundation

/// A single file attachment for a multipart/form-data upload.
public struct AloyNetworkingMedia {
  /// Raw file bytes.
  public let data: Data
  /// Form field name (`Content-Disposition: form-data; name="<key>"`).
  public let key: String
  /// Suggested filename sent in the `Content-Disposition` header.
  public let filename: String
  /// MIME type used in the `Content-Type` part header (e.g. `"image/jpeg"`).
  public let mimeType: String

  public init(data: Data, key: String, filename: String, mimeType: String) {
    self.data = data
    self.key = key
    self.filename = filename
    self.mimeType = mimeType
  }
}
