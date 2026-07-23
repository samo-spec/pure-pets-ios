import Foundation

enum PPPetAdReportReason: String, CaseIterable, Identifiable {
    case inappropriateContent = "inappropriate_content"
    case scamOrFraud = "scam_fraud"
    case wrongCategory = "wrong_category"
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inappropriateContent:
            return PPPetAdLocalization.text(
                "report_reason_inappropriate",
                fallback: "Inappropriate Content"
            )
        case .scamOrFraud:
            return PPPetAdLocalization.text(
                "report_reason_fraud",
                fallback: "Scam or Fraud"
            )
        case .wrongCategory:
            return PPPetAdLocalization.text(
                "report_reason_wrong_category",
                fallback: "Wrong Category"
            )
        case .spam:
            return PPPetAdLocalization.text("report_reason_spam", fallback: "Spam")
        case .other:
            return PPPetAdLocalization.text("report_reason_other", fallback: "Other")
        }
    }
}
