import XCTest
@testable import PureLensCore

final class LensWorkflowTests: XCTestCase {
    func testHappyPath() throws {
        var workflow = LensWorkflow()
        try workflow.send(.cameraAuthorizationChanged(.authorized))
        XCTAssertEqual(workflow.state, .ready)

        try workflow.send(.startScanning)
        XCTAssertEqual(workflow.state, .scanning)

        try workflow.send(.startResolving)
        XCTAssertEqual(workflow.state, .resolving)

        let insight = fixtureInsight()
        try workflow.send(.resolved(insight))
        XCTAssertEqual(workflow.state, .insight(insight))

        try workflow.send(.execute)
        XCTAssertEqual(workflow.state, .executing(insight))

        let receipt = LensActionReceipt(title: "Ready", detail: "Review the cart")
        try workflow.send(.executed(receipt))
        XCTAssertEqual(workflow.state, .success(receipt))
    }

    func testInvalidTransitionThrows() {
        var workflow = LensWorkflow(state: .ready)
        XCTAssertThrowsError(try workflow.send(.execute))
        XCTAssertEqual(workflow.state, .ready)
    }

    func testFailureCanReturnToCamera() throws {
        var workflow = LensWorkflow(state: .resolving)
        let failure = LensFailure(kind: .network, message: "Offline")
        try workflow.send(.failed(failure))
        XCTAssertEqual(workflow.state, .failure(failure))
        try workflow.send(.cancel)
        XCTAssertEqual(workflow.state, .ready)
    }

    private func fixtureInsight() -> LensInsight {
        LensInsight(
            domain: .food,
            confidence: 0.95,
            headline: "Three days left",
            detail: "Based on order history",
            action: LensAction(kind: .prepareCart, title: "Prepare")
        )
    }
}
