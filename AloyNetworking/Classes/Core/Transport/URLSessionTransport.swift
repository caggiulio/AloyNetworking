#if canImport(UIKit) || os(macOS)
import Foundation

@available(macOS 12.0, iOS 15.0, *)
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
