import Foundation

/// Errors from the Qase API client.
public enum APIError: Error, Sendable {
    case notConfigured
    case invalidURL(String)
    case httpError(statusCode: Int, body: String)
    case rateLimited(retryAfter: TimeInterval)
    case networkError(Error)
    case decodingError(Error)
    case payloadTooLarge

    public var localizedDescription: String {
        switch self {
        case .notConfigured:
            "Qase API client is not configured. Set QASE_TESTOPS_API_TOKEN and QASE_TESTOPS_PROJECT."
        case .invalidURL(let url):
            "Invalid URL: \(url)"
        case .httpError(let code, let body):
            "HTTP \(code): \(body)"
        case .rateLimited(let retryAfter):
            "Rate limited. Retry after \(retryAfter)s."
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            "Decoding error: \(error.localizedDescription)"
        case .payloadTooLarge:
            "Payload too large (max 2000 results per batch)."
        }
    }
}
