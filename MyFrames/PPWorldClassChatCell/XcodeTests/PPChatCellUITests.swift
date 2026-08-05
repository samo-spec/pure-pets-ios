import XCTest

/// Copy into your app's XCUITest target and launch the demo/inbox fixture first.
final class PPChatCellUITests: XCTestCase {
    private let conversationID = "conversation-ahmed-invoice"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testChevronExpandsAndCollapsesWithoutNavigation() {
        let app = XCUIApplication()
        app.launch()

        let expand = app.buttons["pp.chat.expand.\(conversationID)"]
        XCTAssertTrue(expand.waitForExistence(timeout: 3))
        expand.tap()

        let input = app.textFields["pp.chat.reply.input.\(conversationID)"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["pp.chat.messaging.\(conversationID)"].exists)

        expand.tap()
        XCTAssertFalse(input.waitForExistence(timeout: 1))
    }

    func testConversationSurfaceOpensMessagingController() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["pp.chat.open.\(conversationID)"].tap()

        XCTAssertTrue(
            app.otherElements["pp.chat.messaging.\(conversationID)"]
                .waitForExistence(timeout: 3)
        )
    }

    func testQuickReplyPopulatesComposerAndSendIsSingleAction() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["pp.chat.expand.\(conversationID)"].tap()
        app.buttons["pp.chat.quickReply.\(conversationID).send-now"].tap()

        let input = app.textFields["pp.chat.reply.input.\(conversationID)"]
        XCTAssertEqual(input.value as? String, "Sending it now")

        let send = app.buttons["pp.chat.reply.send.\(conversationID)"]
        send.tap()
        XCTAssertFalse(send.isEnabled)
    }
}
