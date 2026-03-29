import Testing
@testable import QaseCore

@Suite("StepResult")
struct StepResultTests {

    @Test("apiPayload includes all fields")
    func apiPayloadComplete() {
        let step = StepResult(
            position: 1,
            status: .passed,
            comment: "Did the thing",
            attachments: ["abc123"],
            steps: [
                StepResult(position: 1, status: .failed, comment: "Nested step")
            ]
        )

        let payload = step.apiPayload
        #expect(payload["position"] as? Int == 1)
        #expect(payload["status"] as? String == "passed")
        #expect(payload["comment"] as? String == "Did the thing")
        #expect(payload["attachments"] as? [String] == ["abc123"])

        let nestedSteps = payload["steps"] as? [[String: Any]]
        #expect(nestedSteps?.count == 1)
        #expect(nestedSteps?.first?["status"] as? String == "failed")
    }

    @Test("apiPayload omits nil fields")
    func apiPayloadMinimal() {
        let step = StepResult(position: 2, status: .skipped)
        let payload = step.apiPayload
        #expect(payload["position"] as? Int == 2)
        #expect(payload["status"] as? String == "skipped")
        #expect(payload["comment"] == nil)
        #expect(payload["attachments"] == nil)
        #expect(payload["steps"] == nil)
    }
}
