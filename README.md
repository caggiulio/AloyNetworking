# AloyNetworking
A lightweight networking layer to navigate in the wild internet.

<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a>
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a>

  <h3 align="center">AloyNetworking</h3>
</div>

# AloyNetworking

AloyNetworking library bring together `URLSession`, `Codable`, `Combine` and `async-await` iOS pattern to simplify the HTTP requests send. 

```swift
private let webService: AloyNetworking = {
  var webService = AloyNetworking(baseURL: baseURL, interceptor: CustomWebServiceInterceptor())
  webService.logLevel = .debug
  return webService
}()

...

func getCustomCodable() async throws -> CustomCodable {
  let path = ("/path", [CustomURLQueryItems()])
  let request = AloyNetworkingRequest(method: .get, path: path)

  return try await webService.send(request: request)
}
```

The library works in three modes:
  - Canonical URLSessionDataTask with closures
  - Combine
  - async-await

# How to install
## CocoaPods

```swift
pod 'AloyNetworking'
```

## Swift Package Manager

Add the following dependency to your Package.swift:

```swift
dependencies: [
  .package(url: "https://github.com/caggiulio/AloyNetworking.git", .upToNextMajor(from: "1.0.0"))
]
```

Or add the dependency to your app using Xcode: File => Swift Packages => Add Package Dependency... and type the git repo url: https://github.com/caggiulio/AloyNetworking.git

# Requirements

* iOS 12.0+ / macOS 10.15.2+ / watchOS 5.0+
* Swift 5.2+
* Xcode 11.4+

# How to use

First, you must to create an instance of `AloyNetworking` with `baseURL` and optionally `AloyInterceptorProtocol`(see section [AloyInterceptorProtocol](#AloyInterceptorProtocol) to know more)

```swift
var webService = Networking(baseURL: "https://api.test.com/v1", interceptor: CustomWebServiceInterceptor())
```
At this point the only thing to do is to create a `AloyNetworkingRequest` in this way: 

```swift
let path = ("/path", [CustomURLQueryItems()])
let request = AloyNetworkingRequest(method: .get, path: path)
```
and after make the request. You can choose to handle the request with `Combine` as a `Publisher`, handle it as canonical `URLSessionDataTask` or throws a result with `async-await` iOS pattern.

```swift
// Combine -> return an `AnyPublisher` object of `Decodable` type. The Decodable type is the model that you want to decode.
webService.send(request: request)
```

```swift
// Canonical URLSessionDataTask -> Will be called a closure with results of type (Result<[Decodable], Error>) -> Void. The Decodable type is the model that you want to decode.
webService.send(request) { (results) in
  completion(results)
}
```

```swift
// async-await -> return an object of `Decodable` type or throw an error. The Decodable type is the model that you want to decode.
try await networking.send(request: request)
```

# AloyInterceptorProtocol

The `AloyInterceptorProtocol` is used to adapt URL request and to define retry mechanism of failed requests. The protocol must to implement the `adapt` method and `retry` method and it's optional.

## Adapt
The `adapt` method is used to inspects and adapts the specified `URLRequest` in some manner and return the request. This is an example of use it: 

```swift
func adapt(_ urlRequest: URLRequest) -> URLRequest {
  var request = urlRequest
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")
  return request
}
```

## Retry
This func must be used to execute code before retry a failed request. In Combine version, after the code, you must return a `Future` with `RetryResult`. In the normal version you must call a closure with `RetryResult`. In `async-await` version instead, you must to return the `RetryResult` in a `do-catch` block. Here are the examples: 

```swift
// Combine version
func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error?) -> AnyPublisher<RetryResult, Error> {
  return Future { promise in
    webService.sendRequest(request: request)
      .sink { completion in
         promise(.success(.doNotRetry))
       } receiveValue: { results in
         promise(.success(.retry))
       }
    }
    .eraseToAnyPublisher()
}
```

```swift
// Normal version
func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error?, completion: @escaping (RetryResult) -> Void) {
  webService.sendRequest(request: request) { completionResult in
    switch completionResult {
      case .success(_):
        completion(.retry)
      case .failure(_):
        completion(.doNotRetry)
    }
  }
}
```

```swift
// async-await version
func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error?) async throws -> RetryResult {
  do {
    let _ = try await webService.sendRequest(request)
    return .retry
  } catch {
     return .doNotRetry
  }
}
```
