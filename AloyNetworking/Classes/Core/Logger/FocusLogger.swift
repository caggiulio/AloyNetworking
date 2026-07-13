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
