import Foundation
import XCTest
@testable import PureLensCore

final class LensPolicyTests: XCTestCase {
    func testAcceptsConfidentConfirmedFoodAction() throws {
        let insight = fixture()
        let result = try LensPolicyEngine().validate(insight)
        XCTAssertEqual(result, insight)
    }

    func testRejectsLowConfidence() {
        var insight = fixture()
        insight.confidence = 0.2
        XCTAssertThrowsError(try LensPolicyEngine().validate(insight)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .lowConfidence)
        }
    }

    func testRejectsDiagnosisAndDosage() {
        var diagnosis = fixture()
        diagnosis.domain = .medicine
        diagnosis.safety.medicalContent = .diagnosis
        XCTAssertThrowsError(try LensPolicyEngine().validate(diagnosis)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .medicalDiagnosis)
        }

        var dosage = fixture()
        dosage.domain = .medicine
        dosage.safety.medicalContent = .dosage
        XCTAssertThrowsError(try LensPolicyEngine().validate(dosage)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .medicalDosage)
        }
    }

    func testRejectsWriteActionWithoutConfirmation() {
        var insight = fixture()
        insight.action.requiresConfirmation = false
        XCTAssertThrowsError(try LensPolicyEngine().validate(insight)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .writeWithoutConfirmation)
        }
    }

    func testRejectsExpiredInsight() {
        var insight = fixture()
        insight.expiresAt = Date(timeIntervalSince1970: 100)
        XCTAssertThrowsError(
            try LensPolicyEngine().validate(
                insight,
                now: Date(timeIntervalSince1970: 101)
            )
        ) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .expired)
        }
    }

    func testRejectsUnverifiedMedicineSource() {
        var insight = fixture()
        insight.domain = .medicine
        insight.action = LensAction(
            kind: .openVerifiedMedicine,
            title: "Open",
            payload: ["medicineID": "medicine-1"]
        )
        insight.safety = LensSafety(
            medicalContent: .verifiedPackageInformation,
            hasVerifiedSource: false
        )
        XCTAssertThrowsError(try LensPolicyEngine().validate(insight)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .unverifiedMedicine)
        }
    }

    func testRejectsMissingRequiredPayload() {
        var insight = fixture()
        insight.action.payload = [:]
        XCTAssertThrowsError(try LensPolicyEngine().validate(insight)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .missingPayload("productID"))
        }
    }

    func testAllowsHumanReviewOnlyWhenRoutingToVetOrSupport() throws {
        var insight = fixture()
        insight.domain = .veterinary
        insight.action = LensAction(kind: .bookVet, title: "Book a vet")
        insight.safety = LensSafety(
            medicalContent: .symptomTriage,
            requiresHumanReview: true,
            hasVerifiedSource: true
        )
        XCTAssertNoThrow(try LensPolicyEngine().validate(insight))

        insight.action = LensAction(
            kind: .prepareCart,
            title: "Prepare",
            payload: ["productID": "medicine"]
        )
        XCTAssertThrowsError(try LensPolicyEngine().validate(insight)) { error in
            XCTAssertEqual(error as? LensPolicyRejection, .requiresHumanReview)
        }
    }

    private func fixture() -> LensInsight {
        LensInsight(
            domain: .food,
            confidence: 0.96,
            headline: "Food lasts three days",
            detail: "Based on the last order.",
            action: LensAction(
                kind: .prepareCart,
                title: "Prepare order",
                payload: ["productID": "food-1"]
            )
        )
    }
}
