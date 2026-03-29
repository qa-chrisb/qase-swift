import Foundation

/// Qase API v1 endpoint construction.
enum Endpoints {
    static func baseURL(host: String) -> String {
        "https://api.\(host)/v1"
    }

    static func createRun(host: String, project: String) -> String {
        "\(baseURL(host: host))/run/\(project)"
    }

    static func completeRun(host: String, project: String, runID: Int) -> String {
        "\(baseURL(host: host))/run/\(project)/\(runID)/complete"
    }

    static func bulkResults(host: String, project: String, runID: Int) -> String {
        "\(baseURL(host: host))/result/\(project)/\(runID)/bulk"
    }

    static func uploadAttachment(host: String, project: String) -> String {
        "\(baseURL(host: host))/attachment/\(project)"
    }
}
