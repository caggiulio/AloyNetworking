import AloyNetworking
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
                if let jsonData = try? JSONEncoder().encode(AnyEncodable(body.data)),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    let encoded = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                    if let data = encoded.data(using: String.Encoding.utf8) {
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
