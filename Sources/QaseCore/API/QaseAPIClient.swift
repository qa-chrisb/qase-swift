import Foundation

/// Actor-based HTTP client for the Qase API.
public actor QaseAPIClient {
    private let config: QaseConfig
    private let session: URLSession
    private let maxRetries = 3

    public init(config: QaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Run Management

    /// Creates a new test run and returns its ID.
    public func createRun(title: String, description: String = "", environment: String? = nil) async throws(APIError) -> Int {
        var body: [String: Any] = [
            "title": title,
            "description": description,
            "is_autotest": true,
        ]
        if let environment {
            body["environment_id"] = Int(environment) ?? 0
        }

        let response: CreateRunResponse = try await post(
            url: Endpoints.createRun(host: config.host, project: config.project),
            body: body
        )
        return response.result.id
    }

    /// Marks a test run as complete.
    public func completeRun(runID: Int) async throws(APIError) {
        let _: EmptyResponse = try await post(
            url: Endpoints.completeRun(host: config.host, project: config.project, runID: runID),
            body: nil
        )
    }

    // MARK: - Results

    /// Uploads a batch of test results to a run.
    /// - Parameter jsonData: Pre-serialized JSON body (`{"results": [...]}`).
    public func uploadResults(jsonData: Data, runID: Int) async throws(APIError) {
        let url = Endpoints.bulkResults(host: config.host, project: config.project, runID: runID)
        guard let requestURL = URL(string: url) else { throw .invalidURL(url) }

        var request = makeRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let _: EmptyResponse = try decodeResponse(EmptyResponse.self, from: try await performRequest(request))
    }

    // MARK: - Attachments

    /// Uploads attachments and returns their hashes.
    public func uploadAttachments(_ attachments: [AttachmentInfo]) async throws(APIError) -> [String] {
        guard !attachments.isEmpty else { return [] }

        let boundary = UUID().uuidString
        let url = Endpoints.uploadAttachment(host: config.host, project: config.project)

        guard let requestURL = URL(string: url) else { throw .invalidURL(url) }

        var request = makeRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var bodyData = Data()
        for attachment in attachments {
            bodyData.append("--\(boundary)\r\n".utf8Data)
            bodyData.append("Content-Disposition: form-data; name=\"file[]\"; filename=\"\(attachment.name)\"\r\n".utf8Data)
            bodyData.append("Content-Type: \(attachment.mimeType)\r\n\r\n".utf8Data)
            bodyData.append(attachment.data)
            bodyData.append("\r\n".utf8Data)
        }
        bodyData.append("--\(boundary)--\r\n".utf8Data)
        request.httpBody = bodyData

        let data = try await performRequest(request)
        let response = try decodeResponse(UploadAttachmentResponse.self, from: data)
        return response.result.map(\.hash)
    }

    // MARK: - Internal

    private func post<T: Decodable>(url: String, body: [String: Any]?) async throws(APIError) -> T {
        guard let requestURL = URL(string: url) else { throw .invalidURL(url) }

        var request = makeRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw .decodingError(error)
            }
        }

        let data = try await performRequest(request)
        return try decodeResponse(T.self, from: data)
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(config.apiToken, forHTTPHeaderField: "Token")
        request.timeoutInterval = 30
        return request
    }

    private func performRequest(_ request: URLRequest) async throws(APIError) -> Data {
        for attempt in 0..<maxRetries {
            let data: Data
            let response: URLResponse

            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw .networkError(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw .networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(TimeInterval.init) ?? 60
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(for: .seconds(retryAfter))
                    continue
                }
                throw .rateLimited(retryAfter: retryAfter)
            case 413:
                throw .payloadTooLarge
            default:
                let body = String(data: data, encoding: .utf8) ?? ""
                throw .httpError(statusCode: httpResponse.statusCode, body: body)
            }
        }

        throw .networkError(URLError(.timedOut))
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws(APIError) -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw .decodingError(error)
        }
    }
}

// MARK: - Response Types

struct CreateRunResponse: Decodable {
    let status: Bool
    let result: RunResult

    struct RunResult: Decodable {
        let id: Int
    }
}

struct UploadAttachmentResponse: Decodable {
    let status: Bool
    let result: [AttachmentResult]

    struct AttachmentResult: Decodable {
        let hash: String
        let filename: String
        let mime: String
    }
}

struct EmptyResponse: Decodable {
    let status: Bool
}

// MARK: - Helpers

private extension String {
    var utf8Data: Data { Data(self.utf8) }
}
