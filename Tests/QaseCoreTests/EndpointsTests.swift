import Testing
@testable import QaseCore

@Suite("Endpoints")
struct EndpointsTests {

    @Test("createRun URL")
    func createRunURL() {
        let url = Endpoints.createRun(host: "qase.io", project: "PROJ")
        #expect(url == "https://api.qase.io/v1/run/PROJ")
    }

    @Test("completeRun URL")
    func completeRunURL() {
        let url = Endpoints.completeRun(host: "qase.io", project: "PROJ", runID: 42)
        #expect(url == "https://api.qase.io/v1/run/PROJ/42/complete")
    }

    @Test("bulkResults URL")
    func bulkResultsURL() {
        let url = Endpoints.bulkResults(host: "qase.io", project: "PROJ", runID: 7)
        #expect(url == "https://api.qase.io/v1/result/PROJ/7/bulk")
    }

    @Test("uploadAttachment URL")
    func uploadAttachmentURL() {
        let url = Endpoints.uploadAttachment(host: "qase.io", project: "PROJ")
        #expect(url == "https://api.qase.io/v1/attachment/PROJ")
    }

    @Test("custom host")
    func customHost() {
        let url = Endpoints.createRun(host: "custom.qase.io", project: "TEST")
        #expect(url == "https://api.custom.qase.io/v1/run/TEST")
    }
}
