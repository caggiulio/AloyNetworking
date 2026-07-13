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

  private let session: URLSession
  private let baseURL: URL
  private var port: Int? = nil

  /// The interceptor is used to adapt `URL` request and retry mechanism
  private var interceptor: AloyInterceptorProtocol?

  /// Instance of `FocusLogger`
  private var logger = FocusLogger()

  /// The init of a `AloyNetworking` instance.
  /// - Parameter baseURL: The host baseURL for this instance of `AloyNetworking`
  /// - Parameter interceptor: The interceptor is used to adapt `URL` request and retry mechanism
  public init(baseURL: String, interceptor: AloyInterceptorProtocol? = nil, cachePolicy: NSURLRequest.CachePolicy, port: Int? = nil) {
    guard let url = URL(string: baseURL) else { fatalError("Base URL cannot be invalid!") }
    self.baseURL = url
    self.port = port
    self.interceptor = interceptor

    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = cachePolicy
    session = .init(configuration: configuration)
  }

  // MARK: - iOS > 15 Protocols

  @available(macOS 12.0, iOS 15.0, *)
  public func send<SuccessResponse>(request: AloyNetworkingRequest) async throws -> SuccessResponse where SuccessResponse: Decodable {
    guard let finalUrl = makeUrl(path: request.path.url, queryItems: request.path.query) else {
      throw AloyNetworkingError.invalidUrl
    }

    let adaptedRequest = interceptor?.adapt(request) ?? request
    let finalRequest = makeRequest(url: finalUrl, request: adaptedRequest)
    let data = try await send(request: finalRequest, originalRequest: adaptedRequest)

    return try JSONDecoder().decode(SuccessResponse.self, from: data)
  }

  @available(macOS 12.0, iOS 15.0, *)
  public func send<SuccessResponse>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> SuccessResponse where SuccessResponse: Decodable {
    guard let finalUrl = makeUrl(path: request.path.url, queryItems: request.path.query) else {
      throw AloyNetworkingError.invalidUrl
    }

    let adaptedRequest = interceptor?.adapt(request) ?? request
    let finalRequest = makeMultipartURLRequest(url: finalUrl, request: adaptedRequest, medias: medias, boundary: boundary)

    let data = try await send(request: finalRequest, originalRequest: adaptedRequest)
    return try JSONDecoder().decode(SuccessResponse.self, from: data)
  }

#if canImport(Combine)
  // MARK: - iOS > 13 Protocols

  /// This is the func to use to make an HTTP call in Combine version.
  /// - Parameter request: The `AloyNetworkingRequest` object with HTTP information request.
  /// - Returns  AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(macOS 10.15, iOS 13.0, *)
  public func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest) -> AnyPublisher<SuccessResponse, Error> {
    send(request: request, decoder: JSONDecoder())
  }

  /// This is the func to use to make an HTTP call in Combine version using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  /// - Returns: AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(macOS 10.15, iOS 13.0, *)
  public func send<SuccessResponse>(request: AloyNetworkingRequest, decoder: JSONDecoder) -> AnyPublisher<SuccessResponse, Error> where SuccessResponse: Decodable {
    guard let finalUrl = makeUrl(path: request.path.url, queryItems: request.path.query) else {
      return Fail(error: AloyNetworkingError.invalidUrl)
        .eraseToAnyPublisher()
    }

    let adaptedRequest = interceptor?.adapt(request) ?? request
    let finalRequest = makeRequest(url: finalUrl, request: adaptedRequest)

    return send(request: finalRequest, originalRequest: adaptedRequest)
      .decode(type: SuccessResponse.self, decoder: decoder)
      .eraseToAnyPublisher()
  }

  /// This is the func to use to make an HTTP multipart call in Combine version.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  /// - Returns: AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(macOS 10.15, iOS 13.0, *)
  public func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) -> AnyPublisher<SuccessResponse, Error> {
    send(request: request, medias: medias, boundary: boundary, decoder: JSONDecoder())
  }

  /// This is the func to use to make an HTTP multipart call in Combine version using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  /// - Returns: AnyPublisher<SuccessResponse, Error> where `SuccessResponse` is a Decodable to decode in HTTP response.
  @available(macOS 10.15, iOS 13.0, *)
  public func send<SuccessResponse>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String, decoder: JSONDecoder) -> AnyPublisher<SuccessResponse, Error> where SuccessResponse: Decodable {
    guard let finalUrl = makeUrl(path: request.path.url, queryItems: request.path.query) else {
      return Fail(error: AloyNetworkingError.invalidUrl)
        .eraseToAnyPublisher()
    }

    let adaptedRequest = interceptor?.adapt(request) ?? request
    let finalRequest = makeMultipartURLRequest(url: finalUrl, request: adaptedRequest, medias: medias, boundary: boundary)

    return send(request: finalRequest, originalRequest: adaptedRequest)
      .decode(type: SuccessResponse.self, decoder: decoder)
      .eraseToAnyPublisher()
  }
#endif

  // MARK: - iOS < 13 Protocols

  /// This is the func to use to make an HTTP call.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  public func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, completion: ((Result<SuccessResponse, Error>) -> Void)?) {
    send(request: request, decoder: JSONDecoder(), completion: completion)
  }

  /// This is the func to use to make an HTTP call using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  public func send<SuccessResponse>(request: AloyNetworkingRequest, decoder: JSONDecoder, completion: ((Result<SuccessResponse, Error>) -> Void)?) where SuccessResponse: Decodable {
    guard let finalUrl = makeUrl(path: request.path.url, queryItems: request.path.query) else {
      completion?(.failure(AloyNetworkingError.invalidUrl))
      return
    }

    let adaptedRequest = interceptor?.adapt(request) ?? request
    let request = makeRequest(url: finalUrl, request: adaptedRequest)
    send(request: request, originalRequest: adaptedRequest, completion: { result in
      switch result {
        case let .success(result):
          do {
            let decodedObject = try decoder.decode(SuccessResponse.self, from: result)
            completion?(.success(decodedObject))
          } catch {
            completion?(.failure(AloyNetworkingError.decodingFailed(error: error)))
          }
        case let .failure(error):
          completion?(.failure(error))
      }
    })
  }

  /// This is the func to use to make an HTTP multipart call.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  public func send<SuccessResponse: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String, completion: ((Result<SuccessResponse, Error>) -> Void)?) {
    send(request: request, medias: medias, boundary: boundary, decoder: JSONDecoder(), completion: completion)
  }

  /// This is the func to use to make an HTTP multipart call using a custom decoder.
  /// - Parameters:
  ///   - request: The `AloyNetworkingRequest` object with HTTP information request.
  ///   - medias: Array of `AloyNetworkingMedia` object with media informations to upload.
  ///   - boundary: The boundary of HTTP multipart request.
  ///   - decoder: The `JSONDecoder` used to decode the response.
  ///   - completion: The closure with `Result`. `SuccessResponse` is a Decodable to decode in HTTP response.
  public func send<SuccessResponse>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String, decoder: JSONDecoder, completion: ((Result<SuccessResponse, Error>) -> Void)?) where SuccessResponse: Decodable {
    guard let finalUrl = makeUrl(path: request.path.url, queryItems: request.path.query) else {
      completion?(.failure(AloyNetworkingError.invalidUrl))
      return
    }

    let adaptedRequest = interceptor?.adapt(request) ?? request
    let request = makeMultipartURLRequest(url: finalUrl, request: adaptedRequest, medias: medias, boundary: boundary)
    send(request: request, originalRequest: adaptedRequest, completion: { result in
      switch result {
        case let .success(result):
          do {
            let decodedObject = try decoder.decode(SuccessResponse.self, from: result)
            completion?(.success(decodedObject))
          } catch {
            completion?(.failure(AloyNetworkingError.decodingFailed(error: error)))
          }

        case let .failure(error):
          completion?(.failure(error))
      }
    })
  }
}

// MARK: - Private methods

private extension AloyNetworking {
  /// This method is used to build an `URL` object
  func makeUrl(path: String, queryItems: [URLQueryItem]?) -> URL? {
    var components = URLComponents()
    components.scheme = baseURL.scheme
    components.host = baseURL.host
    components.path = baseURL.path + path
    components.queryItems = queryItems
    components.port = port
    guard let url = components.url else { return nil }
    return url
  }

  /// This method is used to build an `URLRequest` object
  func makeRequest(url: URL, request: AloyNetworkingRequest) -> URLRequest {
    var finalRequest = URLRequest(url: url)
    finalRequest.httpMethod = request.method.rawValue

    request.header?.forEach { key, value in
      if let value = value as? String {
        finalRequest.setValue(value, forHTTPHeaderField: key)
      }
    }

    switch request.body?.encoding {
      case .json:
        guard let dictionary = request.body?.data.dictionary else { break }
        finalRequest.httpBody = try? JSONSerialization.data(withJSONObject: dictionary)
      case .urlEncoded:
        guard let params = request.body?.data.dictionary else { break }
        let httpBody = params
          .map { key, value -> String in
            "\(key)=\(value)"
          }
          .joined(separator: "&")
          .data(using: String.Encoding.utf8)
        finalRequest.httpBody = httpBody
      case .none:
        break
    }

    return finalRequest
  }

  /// This method is used to build an `URLRequest` object
  func makeMultipartURLRequest(url: URL, request: AloyNetworkingRequest, medias: [AloyNetworkingMedia]?, boundary: String) -> URLRequest {
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method.rawValue
    request.header?.forEach { key, value in
      if let value = value as? String {
        urlRequest.setValue(value, forHTTPHeaderField: key)
      }
    }
    urlRequest.httpBody = makeMultipartBody(request: request, medias: medias, boundary: boundary)
    return urlRequest
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
  func send(request: URLRequest, originalRequest: AloyNetworkingRequest) async throws -> Data {
    let finalRequest = request

    logger.logRequest(finalRequest)

    do {
      let (data, response) = try await session.data(for: finalRequest)
      guard let httpRespone = response as? HTTPURLResponse else {
        throw AloyNetworkingError.invalidHTTPResponse
      }

      let statusCode = httpRespone.statusCode
      switch statusCode {
        case 200 ... 299:
          logger.logResponse(response, data: data)
          return data

        default:
          let error = AloyNetworkingError.underlying(
            statusCode: statusCode,
            data: data
          )

          logger.logResponse(response, data: data, error: error)

          return try await shouldRetry(originalRequest: originalRequest, error: error)
      }
    } catch {
      throw error
    }
  }

  /// Func used to understand if the system should retry the request in async await version
  func shouldRetry(originalRequest: AloyNetworkingRequest, error: Error) async throws -> Data {
    guard let interceptor = interceptor else { throw error }

    let retryResult = try await interceptor.retry(originalRequest, dueTo: error)
    switch retryResult {
      case .retry:
        guard let finalUrl = makeUrl(path: originalRequest.path.url, queryItems: originalRequest.path.query) else {
          throw AloyNetworkingError.invalidUrl
        }
        let urlRequest = makeRequest(url: finalUrl, request: originalRequest)
        return try await send(request: urlRequest, originalRequest: originalRequest)
      case .doNotRetry:
        throw error
    }
  }
}

// MARK: - Functions used with combine

#if canImport(Combine)
@available(macOS 10.15, iOS 13.0, *)
private extension AloyNetworking {
  /// This func is the final step to make an HTTP call in Combine version using the `dataTaskPublisher`func.
  func send(request: URLRequest, originalRequest: AloyNetworkingRequest) -> AnyPublisher<Data, Error> {
    func publisher(_ output: URLSession.DataTaskPublisher.Output) -> AnyPublisher<Data, Error> {
      let response = output.response
      let data = output.data

      guard let httpResponse = output.response as? HTTPURLResponse else {
        return Fail(error: AloyNetworkingError.invalidHTTPResponse)
          .eraseToAnyPublisher()
      }

      let statusCode = httpResponse.statusCode
      switch statusCode {
        case 200 ... 299:
          logger.logResponse(response, data: data)
          return Result.success(data)
            .publisher
            .eraseToAnyPublisher()
        default:
          let error = AloyNetworkingError.underlying(
            statusCode: statusCode,
            data: data
          )

          logger.logResponse(response, data: data, error: error)

          return Fail(error: error).eraseToAnyPublisher()
      }
    }

    logger.logRequest(request)

    return session.dataTaskPublisher(for: request)
      .mapError { $0 }
      .flatMap { publisher($0) }
      .eraseToAnyPublisher()
  }
}
#endif

// MARK: - Functions used without combine

private extension AloyNetworking {
  /// This func is the final step to make an HTTP call in non Comibne version using the `dataTask`func.
  func send(request: URLRequest, originalRequest: AloyNetworkingRequest, completion: ((Result<Data, Error>) -> Void)?) {
    let finalRequest = request

    logger.logRequest(finalRequest)

    let task = session.dataTask(with: finalRequest) { data, response, error in
      self.logger.logResponse(response, data: data, error: error)

      if let httpResponse = response as? HTTPURLResponse {
        let statusCode = httpResponse.statusCode

        switch statusCode {
          case 200 ... 299:
            if let data = data {
              completion?(.success(data))
            } else {
              completion?(.failure(AloyNetworkingError.underlying(statusCode: statusCode, data: nil)))
            }
          default:
            completion?(.failure(AloyNetworkingError.underlying(statusCode: statusCode, data: data)))
        }
      } else {
        completion?(.failure(AloyNetworkingError.invalidHTTPResponse))
      }
    }
    task.resume()
  }
}
