import Foundation

/// An attachment to be uploaded to Qase alongside a test result.
public struct AttachmentInfo: Sendable {
    public var data: Data
    public var name: String
    public var mimeType: String

    /// Hash returned by the Qase API after upload. Nil until uploaded.
    public var hash: String?

    public init(data: Data, name: String, mimeType: String) {
        self.data = data
        self.name = name
        self.mimeType = mimeType
    }
}
