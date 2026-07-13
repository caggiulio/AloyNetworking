import Foundation

public protocol HTTPTransport {
    func execute(_ request: AloyNetworkingRequest) async throws -> (Data, Int)
}
