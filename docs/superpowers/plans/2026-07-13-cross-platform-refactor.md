# AloyNetworking Cross-Platform Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor AloyNetworking to support iOS and Android by replacing URLSession/Combine/URLRequest with a transport-abstracted, async/await-only architecture.

**Architecture:** A new `HTTPTransport` protocol abstracts the HTTP layer — `URLSessionTransport` implements it for iOS using URLSession, `NIOTransport` implements it for Android using AsyncHTTPClient. `AloyNetworking` holds all shared logic (status codes, retry, decode) and is initialized with a transport. Interceptors operate on `AloyNetworkingRequest` instead of `URLRequest`, making them genuinely cross-platform.

**Tech Stack:** Swift 5.9+, async/await, AsyncHTTPClient (Android), URLSession (iOS), NIOFoundationCompat (Android)

## Global Constraints

- Drop Combine (`AnyPublisher`) entirely — async/await only
- Drop completion handler variants — async/await only
- Drop `platforms: [.iOS(.v14)]` from Package.swift — no platform restriction on core target
- `AloyNetworkingRequest` is the universal request type — never `URLRequest` in public API
- Transport implementations live in separate SPM targets with conditional platform availability
- All new code: no comments unless non-obvious

---

## File Structure

**Modified:**
- `Package.swift` — remove platform restriction, add NIO targets, add conditional transport targets
- `AloyNetworking/Classes/Core/Base/AloyNetworkingProtocol.swift` — strip Combine/callbacks, keep only async throws
- `AloyNetworking/Classes/Core/Base/AloyNetworking.swift` — strip URLSession/Combine, use HTTPTransport
- `AloyNetworking/Classes/Core/Interceptor/AloyInterceptorProtocol.swift` — replace URLRequest/URLSession with AloyNetworkingRequest
- `AloyNetworking/Classes/Core/Error/AloyNetworkingError.swift` — remove URLError/URLResponse types
- `AloyNetworking/Classes/Core/Logger/FocusLogger.swift` — replace URLRequest with AloyNetworkingRequest

**Created:**
- `AloyNetworking/Classes/Core/Transport/HTTPTransport.swift` — protocol
- `AloyNetworking/Classes/Core/Transport/URLSessionTransport.swift` — iOS implementation
- `AloyNetworking/Classes/Core/Transport/NIOTransport.swift` — Android/Linux implementation

**Deleted:**
- No files deleted — Combine methods removed from existing files

---

### Task 1: Package.swift — Remove Platform Lock, Add Transport Targets

**Files:**
- Modify: `Package.swift`

**Interfaces:**
- Produces: `AloyNetworking` target (no platform restriction), `AloyNetworkingNIO` target (Linux/Android only)

- [ ] **Step 1: Replace Package.swift content**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "AloyNetworking",
  products: [
    .library(name: "AloyNetworking", targets: ["AloyNetworking"]),
    .library(name: "AloyNetworkingNIO", targets: ["AloyNetworkingNIO"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.21.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
  ],
  targets: [
    .target(
      name: "AloyNetworking",
      dependencies: [],
      path: "AloyNetworking/"
    ),
    .target(
      name: "AloyNetworkingNIO",
      dependencies: [
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
      ],
      path: "AloyNetworkingNIO/"
    ),
    .testTarget(
      name: "AloyNetworkingTests",
      dependencies: ["AloyNetworking"]
    ),
  ]
)
```

- [ ] **Step 2: Create NIO target directory**

```bash
mkdir -p /Users/giulcag/Developer/AloyNetworking/AloyNetworkingNIO
```

- [ ] **Step 3: Verify package resolves**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift package resolve
```

Expected: resolves without errors, fetches async-http-client and swift-nio.

- [ ] **Step 4: Commit**

```bash
git add Package.swift AloyNetworkingNIO/
git commit -m "chore: remove iOS platform lock, add AloyNetworkingNIO target"
```

---

### Task 2: HTTPTransport Protocol

**Files:**
- Create: `AloyNetworking/Classes/Core/Transport/HTTPTransport.swift`

**Interfaces:**
- Consumes: `AloyNetworkingRequest` (existing)
- Produces: `protocol HTTPTransport { func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int) }`

- [ ] **Step 1: Create transport directory**

```bash
mkdir -p /Users/giulcag/Developer/AloyNetworking/AloyNetworking/Classes/Core/Transport
```

- [ ] **Step 2: Write HTTPTransport.swift**

```swift
import Foundation

public protocol HTTPTransport {
    func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int)
}
```

- [ ] **Step 3: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add AloyNetworking/Classes/Core/Transport/HTTPTransport.swift
git commit -m "feat: add HTTPTransport protocol"
```

---

### Task 3: URLSessionTransport (iOS)

**Files:**
- Create: `AloyNetworking/Classes/Core/Transport/URLSessionTransport.swift`

**Interfaces:**
- Consumes: `protocol HTTPTransport` (Task 2), `AloyNetworkingRequest` (existing)
- Produces: `public struct URLSessionTransport: HTTPTransport`

- [ ] **Step 1: Write URLSessionTransport.swift**

```swift
#if canImport(UIKit) || os(macOS)
import Foundation

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int) {
        guard let url = buildURL(from: request) else {
            throw AloyNetworkingError.invalidUrl
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        request.header?.forEach { key, value in
            if let value = value as? String {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = request.body {
            switch body.encoding {
            case .json:
                if let data = try? JSONEncoder().encode(AnyEncodable(body.data)) {
                    urlRequest.httpBody = data
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            case .urlEncoded:
                if let dict = body.data.dictionary {
                    let encoded = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                    urlRequest.httpBody = encoded.data(using: .utf8)
                    urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            }
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AloyNetworkingError.invalidHTTPResponse
        }
        return (data, httpResponse.statusCode)
    }

    private func buildURL(from request: AloyNetworkingRequest) -> URL? {
        var components = URLComponents(string: request.path.url)
        components?.queryItems = request.path.query
        return components?.url
    }
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Encodable) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
#endif
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AloyNetworking/Classes/Core/Transport/URLSessionTransport.swift
git commit -m "feat: add URLSessionTransport for iOS/macOS"
```

---

### Task 4: NIOTransport (Android/Linux)

**Files:**
- Create: `AloyNetworkingNIO/NIOTransport.swift`

**Interfaces:**
- Consumes: `protocol HTTPTransport` (Task 2), `AloyNetworkingRequest` (existing — imported via AloyNetworking)
- Produces: `public struct NIOTransport: HTTPTransport`

- [ ] **Step 1: Write NIOTransport.swift**

```swift
import AsyncHTTPClient
import Foundation
import NIOFoundationCompat
import NIOHTTP1

public struct NIOTransport: HTTPTransport {
    public init() {}

    public func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int) {
        var httpRequest = HTTPClientRequest(url: buildURL(from: request))
        httpRequest.method = HTTPMethod(rawValue: request.method.rawValue)

        request.header?.forEach { key, value in
            if let value = value as? String {
                httpRequest.headers.add(name: key, value: value)
            }
        }

        if let body = request.body {
            switch body.encoding {
            case .json:
                if let data = try? JSONEncoder().encode(AnyEncodable(body.data)) {
                    httpRequest.headers.add(name: "Content-Type", value: "application/json")
                    httpRequest.body = .bytes(data)
                }
            case .urlEncoded:
                if let dict = body.data.dictionary {
                    let encoded = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                    if let data = encoded.data(using: .utf8) {
                        httpRequest.headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
                        httpRequest.body = .bytes(data)
                    }
                }
            }
        }

        let response = try await HTTPClient.shared.execute(httpRequest, timeout: .seconds(30))
        let buffer = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let data = Data(buffer: buffer)
        return (data, Int(response.status.code))
    }

    private func buildURL(from request: AloyNetworkingRequest) -> String {
        guard let queryItems = request.path.query, !queryItems.isEmpty else {
            return request.path.url
        }
        var components = URLComponents(string: request.path.url)
        components?.queryItems = queryItems
        return components?.url?.absoluteString ?? request.path.url
    }
}

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Encodable) { _encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworkingNIO
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AloyNetworkingNIO/NIOTransport.swift
git commit -m "feat: add NIOTransport for Android/Linux via AsyncHTTPClient"
```

---

### Task 5: Refactor AloyInterceptorProtocol — Remove URLRequest/URLSession/Combine

**Files:**
- Modify: `AloyNetworking/Classes/Core/Interceptor/AloyInterceptorProtocol.swift`

**Interfaces:**
- Produces:
  - `protocol RequestAdapter { func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest }`
  - `protocol RetryAdapter { func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult }`
  - `protocol AloyInterceptorProtocol: RequestAdapter, RetryAdapter {}`

- [ ] **Step 1: Replace AloyInterceptorProtocol.swift**

```swift
import Foundation

public protocol RequestAdapter {
    func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest
}

public protocol RetryAdapter {
    func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult
}

public protocol AloyInterceptorProtocol: RequestAdapter, RetryAdapter {}

public extension AloyInterceptorProtocol {
    func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest {
        return request
    }

    func retry(_ request: AloyNetworkingRequest, dueTo error: Error) async throws -> RetryResult {
        return .doNotRetry
    }
}

public enum RetryResult {
    case retry
    case doNotRetry
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AloyNetworking/Classes/Core/Interceptor/AloyInterceptorProtocol.swift
git commit -m "refactor: replace URLRequest/Combine in interceptor with AloyNetworkingRequest + async"
```

---

### Task 6: Refactor AloyNetworkingError — Remove Apple-Specific Types

**Files:**
- Modify: `AloyNetworking/Classes/Core/Error/AloyNetworkingError.swift`

**Interfaces:**
- Produces: `public enum AloyNetworkingError: Error` with cases: `invalidUrl`, `invalidHTTPResponse`, `decodingFailed(error: Error)`, `other(error: Error)`, `underlying(statusCode: Int, data: Data?)`

- [ ] **Step 1: Replace AloyNetworkingError.swift**

```swift
import Foundation

public enum AloyNetworkingError: Error {
    case invalidUrl
    case invalidHTTPResponse
    case decodingFailed(error: Error)
    case other(error: Error)
    case underlying(statusCode: Int, data: Data?)
}
```

Note: removed `sessionFailed(error: URLError)` and `URLResponse` from `underlying` — these are Apple-specific. Status code int is cross-platform.

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: BUILD SUCCEEDED (or errors only in AloyNetworking.swift which we fix next)

- [ ] **Step 3: Commit**

```bash
git add AloyNetworking/Classes/Core/Error/AloyNetworkingError.swift
git commit -m "refactor: remove URLError/URLResponse from AloyNetworkingError"
```

---

### Task 7: Refactor FocusLogger — Replace URLRequest with AloyNetworkingRequest

**Files:**
- Modify: `AloyNetworking/Classes/Core/Logger/FocusLogger.swift`

**Interfaces:**
- Consumes: `AloyNetworkingRequest` (existing), `FocusLoggerLevel` (existing)
- Produces: `class FocusLogger` with `logRequest(_ request: AloyNetworkingRequest)`, `logResponse(statusCode: Int, data: Data?, error: Error?)`

- [ ] **Step 1: Replace FocusLogger.swift**

```swift
import Foundation

class FocusLogger {
    var logLevel = FocusLoggerLevel.debug

    func logRequest(_ request: AloyNetworkingRequest) {
        guard logLevel != .none else { return }
        print("\n⬆️ ----- START REQUEST ----- ⬆️")
        print("    -- Url: \(request.path.url)")
        print("    -- Method: \(request.method.rawValue)")
        if let headers = request.header, !headers.isEmpty {
            print("    -- Headers:")
            headers.forEach { print("        -- \($0.key): \($0.value)") }
        }
        print("⬆️ ----- END REQUEST ----- ⬆️")
    }

    func logResponse(statusCode: Int, data: Data?, error: Error?) {
        guard logLevel != .none else { return }
        print("\n⬇️ ----- START RESPONSE ----- ⬇️")
        if statusCode >= 200, statusCode < 300 {
            print("    -- Status Code: ✅ \(statusCode)")
        } else {
            print("    -- Status Code: ❌ \(statusCode)")
        }
        if logLevel == .debug {
            if let data, let body = String(data: data, encoding: .utf8) {
                print("    -- Body: \(body)")
            }
            if let error {
                print("    -- Error: 🚨 \(error.localizedDescription)")
            }
        }
        print("⬇️ ----- END RESPONSE ----- ⬇️")
    }
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

- [ ] **Step 3: Commit**

```bash
git add AloyNetworking/Classes/Core/Logger/FocusLogger.swift
git commit -m "refactor: replace URLRequest with AloyNetworkingRequest in FocusLogger"
```

---

### Task 8: Refactor AloyNetworkingProtocol — Async Only

**Files:**
- Modify: `AloyNetworking/Classes/Core/Base/AloyNetworkingProtocol.swift`

**Interfaces:**
- Produces:
  - `func send<T: Decodable>(request: AloyNetworkingRequest) async throws -> T`
  - `func send<T: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> T`

- [ ] **Step 1: Replace AloyNetworkingProtocol.swift**

```swift
import Foundation

public protocol AloyNetworkingProtocol {
    func send<T: Decodable>(request: AloyNetworkingRequest) async throws -> T
    func send<T: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> T
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: errors only in AloyNetworking.swift (fixed in Task 9)

- [ ] **Step 3: Commit**

```bash
git add AloyNetworking/Classes/Core/Base/AloyNetworkingProtocol.swift
git commit -m "refactor: strip Combine/callbacks from AloyNetworkingProtocol, async-only"
```

---

### Task 9: Refactor AloyNetworking Core Class

**Files:**
- Modify: `AloyNetworking/Classes/Core/Base/AloyNetworking.swift`

**Interfaces:**
- Consumes: `HTTPTransport` (Task 2), `AloyInterceptorProtocol` (Task 5), `AloyNetworkingError` (Task 6), `FocusLogger` (Task 7), `AloyNetworkingProtocol` (Task 8)
- Produces: `public class AloyNetworking: AloyNetworkingProtocol` initialized with `transport: HTTPTransport`

- [ ] **Step 1: Replace AloyNetworking.swift**

```swift
import Foundation

public class AloyNetworking: AloyNetworkingProtocol {
    public var logLevel: FocusLoggerLevel {
        get { logger.logLevel }
        set { logger.logLevel = newValue }
    }

    private let transport: HTTPTransport
    private let interceptor: AloyInterceptorProtocol?
    private var logger = FocusLogger()

    public init(transport: HTTPTransport, interceptor: AloyInterceptorProtocol? = nil) {
        self.transport = transport
        self.interceptor = interceptor
    }

    public func send<T: Decodable>(request: AloyNetworkingRequest) async throws -> T {
        let finalRequest = interceptor?.adapt(request) ?? request
        logger.logRequest(finalRequest)

        let (data, statusCode) = try await transport.execute(finalRequest)
        logger.logResponse(statusCode: statusCode, data: data, error: nil)

        return try handleResponse(data: data, statusCode: statusCode, originalRequest: finalRequest)
    }

    public func send<T: Decodable>(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) async throws -> T {
        let finalRequest = interceptor?.adapt(request) ?? request
        logger.logRequest(finalRequest)

        // Multipart body built here, passed via a wrapper request
        let multipartRequest = buildMultipartRequest(from: finalRequest, medias: medias, boundary: boundary)
        let (data, statusCode) = try await transport.execute(multipartRequest)
        logger.logResponse(statusCode: statusCode, data: data, error: nil)

        return try handleResponse(data: data, statusCode: statusCode, originalRequest: finalRequest)
    }
}

private extension AloyNetworking {
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

    func buildMultipartRequest(from request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) -> AloyNetworkingRequest {
        let body = makeMultipartData(request: request, medias: medias, boundary: boundary)
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

    func makeMultipartData(request: AloyNetworkingRequest, medias: [AloyNetworkingMedia], boundary: String) -> Data {
        let lineBreak = "\r\n"
        var body = Data()

        func append(_ string: String) {
            if let data = string.data(using: .utf8) { body.append(data) }
        }

        request.body?.data.dictionary?.forEach { param in
            append("--\(boundary)\(lineBreak)")
            append("Content-Disposition: form-data; name=\"\(param.key)\"\(lineBreak)\(lineBreak)")
            append("\(param.value)\(lineBreak)")
        }

        medias.forEach { media in
            append("--\(boundary)\(lineBreak)")
            append("Content-Disposition: form-data; name=\"\(media.key)\"; filename=\"\(media.filename)\"\(lineBreak)")
            append("Content-Type: \(media.mimeType)\(lineBreak)\(lineBreak)")
            body.append(media.data)
            append(lineBreak)
        }

        append("--\(boundary)--\(lineBreak)")
        return body
    }
}

// Shim to pass raw Data through the Encodable body slot
private struct RawDataBody: Encodable {
    let data: Data
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
}
```

- [ ] **Step 2: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AloyNetworking/Classes/Core/Base/AloyNetworking.swift
git commit -m "refactor: AloyNetworking now transport-based, async-only, cross-platform"
```

---

### Task 10: Update AloyNetworkingRequest Path — Support Full URLs

**Files:**
- Modify: `AloyNetworking/Classes/Core/Models/AloyNetworkingRequest.swift`

**Context:** Current `Path` type has `url: String` intended as a relative path appended to a base URL. Since we removed the `baseURL` from `AloyNetworking` init (transport now handles URL construction), the path must be a full URL or we need to restore base URL support. The cleanest cross-platform solution: keep `baseURL` on `AloyNetworking`, pass it to transport via the request.

- [ ] **Step 1: Add baseURL to AloyNetworking init and prepend in execute**

Add `baseURL` back to `AloyNetworking`:

```swift
// In AloyNetworking.swift, update init and add property:
private let baseURL: String

public init(baseURL: String, transport: HTTPTransport, interceptor: AloyInterceptorProtocol? = nil) {
    self.baseURL = baseURL
    self.transport = transport
    self.interceptor = interceptor
}
```

Update `send` to prepend baseURL before passing to transport:

```swift
// In send<T>(request:):
var mutableRequest = finalRequest
mutableRequest.path = (url: baseURL + finalRequest.path.url, query: finalRequest.path.query)
let (data, statusCode) = try await transport.execute(mutableRequest)
```

Make `AloyNetworkingRequest.path` mutable (`var path: Path`).

- [ ] **Step 2: Update AloyNetworkingRequest.swift**

```swift
import Foundation

public struct AloyNetworkingRequest {
    public typealias Path = (url: String, query: [URLQueryItem]?)
    public typealias Body = (data: Encodable, encoding: Encoding)

    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    public enum Encoding {
        case json
        case urlEncoded
    }

    public var method: HTTPMethod
    public var path: Path
    public var header: [String: Any]?
    public var body: Body?

    public init(method: HTTPMethod, path: Path, header: [String: Any]? = nil, body: Body? = nil) {
        self.method = method
        self.path = path
        self.header = header
        self.body = body
    }
}
```

- [ ] **Step 3: Update AloyNetworking.swift init and send**

```swift
// Updated init
public init(baseURL: String, transport: HTTPTransport, interceptor: AloyInterceptorProtocol? = nil) {
    self.baseURL = baseURL
    self.transport = transport
    self.interceptor = interceptor
}

private let baseURL: String

// Updated send - prepend baseURL
public func send<T: Decodable>(request: AloyNetworkingRequest) async throws -> T {
    var adapted = interceptor?.adapt(request) ?? request
    adapted.path = (url: baseURL + adapted.path.url, query: adapted.path.query)
    logger.logRequest(adapted)
    let (data, statusCode) = try await transport.execute(adapted)
    logger.logResponse(statusCode: statusCode, data: data, error: nil)
    return try await handleResponse(data: data, statusCode: statusCode, originalRequest: adapted)
}
```

Apply same baseURL prepend in the multipart `send` overload.

- [ ] **Step 4: Verify compiles**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift build --target AloyNetworking
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add AloyNetworking/Classes/Core/Models/AloyNetworkingRequest.swift AloyNetworking/Classes/Core/Base/AloyNetworking.swift
git commit -m "feat: restore baseURL on AloyNetworking init, prepend in transport call"
```

---

### Task 11: Update AloyNetworkingTests

**Files:**
- Modify: `Tests/AloyNetworkingTests/AloyNetworkingTests.swift`

**Interfaces:**
- Consumes: `AloyNetworking`, `AloyNetworkingRequest`, `HTTPTransport`

- [ ] **Step 1: Write mock transport and basic tests**

```swift
import XCTest
@testable import AloyNetworking

final class AloyNetworkingTests: XCTestCase {

    struct MockTransport: HTTPTransport {
        let responseData: Data
        let statusCode: Int

        func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int) {
            return (responseData, statusCode)
        }
    }

    struct SampleResponse: Decodable, Equatable {
        let id: Int
        let name: String
    }

    func testSuccessfulDecode() async throws {
        let json = #"{"id":1,"name":"Test"}"#.data(using: .utf8)!
        let transport = MockTransport(responseData: json, statusCode: 200)
        let client = AloyNetworking(baseURL: "https://api.example.com", transport: transport)

        let result: SampleResponse = try await client.send(
            request: AloyNetworkingRequest(method: .get, path: (url: "/item", query: nil))
        )

        XCTAssertEqual(result, SampleResponse(id: 1, name: "Test"))
    }

    func testUnauthorizedThrows() async throws {
        let transport = MockTransport(responseData: Data(), statusCode: 401)
        let client = AloyNetworking(baseURL: "https://api.example.com", transport: transport)

        do {
            let _: SampleResponse = try await client.send(
                request: AloyNetworkingRequest(method: .get, path: (url: "/item", query: nil))
            )
            XCTFail("Expected throw")
        } catch AloyNetworkingError.underlying(let statusCode, _) {
            XCTAssertEqual(statusCode, 401)
        }
    }

    func testInterceptorAdapts() async throws {
        struct AuthInterceptor: AloyInterceptorProtocol {
            func adapt(_ request: AloyNetworkingRequest) -> AloyNetworkingRequest {
                var r = request
                r.header = ["Authorization": "Bearer token123"]
                return r
            }
        }

        var capturedRequest: AloyNetworkingRequest?
        struct CapturingTransport: HTTPTransport {
            let capture: (AloyNetworkingRequest) -> Void
            func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int) {
                capture(request)
                return (#"{"id":1,"name":"x"}"#.data(using: .utf8)!, 200)
            }
        }

        let transport = CapturingTransport { capturedRequest = $0 }
        let client = AloyNetworking(baseURL: "https://api.example.com", transport: transport, interceptor: AuthInterceptor())

        let _: SampleResponse = try await client.send(
            request: AloyNetworkingRequest(method: .get, path: (url: "/item", query: nil))
        )

        XCTAssertEqual(capturedRequest?.header?["Authorization"] as? String, "Bearer token123")
    }
}
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/giulcag/Developer/AloyNetworking && swift test
```

Expected: 3 tests pass

- [ ] **Step 3: Commit**

```bash
git add Tests/AloyNetworkingTests/AloyNetworkingTests.swift
git commit -m "test: add cross-platform unit tests with mock transport"
```

---

## Self-Review

**Spec coverage:**
- ✓ Drop Combine — removed from Protocol and Interceptor
- ✓ Drop callbacks — removed from Protocol and AloyNetworking
- ✓ `AloyNetworkingRequest` universal type in interceptors
- ✓ Transport protocol with URLSession + NIO implementations
- ✓ Status code handling centralized in AloyNetworking
- ✓ Retry via interceptor preserved, now async
- ✓ Logger updated to not use URLRequest
- ✓ Package.swift platform lock removed
- ✓ baseURL preserved on AloyNetworking init

**Gaps identified and addressed:**
- Task 10 added to handle baseURL (was missing from initial design)
- `RawDataBody` shim needed for multipart — included in Task 9

**Type consistency:**
- `AloyNetworkingError.underlying(statusCode: Int, data: Data?)` — used consistently in Task 6, 9, 11
- `HTTPTransport.execute` signature `(AloyNetworkingRequest) async throws -> (Data, Int)` — consistent Tasks 2, 3, 4, 9, 11
- `AloyInterceptorProtocol.adapt` takes/returns `AloyNetworkingRequest` — consistent Tasks 5, 9, 11
