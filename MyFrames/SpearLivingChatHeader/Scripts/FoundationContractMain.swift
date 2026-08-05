import Foundation

@main
struct FoundationContractMain {
  static func main() {
    var failures: [String] = []

    check(
      SpearChatHeaderCopy.english.presenceText(for: .typing) == "Typing",
      "typing copy returns explicitly",
      failures: &failures
    )
    check(
      SpearChatHeaderCopy.english.callText(elapsedSeconds: 138) == "Secure call · 02:18",
      "English call duration is formatted",
      failures: &failures
    )
    check(
      SpearChatHeaderCopy.arabic.callText(elapsedSeconds: 138) == "مكالمة آمنة · ٠٢:١٨",
      "Arabic call duration uses locale digits",
      failures: &failures
    )

    let metricsModel = SpearChatHeaderModel(
      id: "metrics",
      name: "Ahmed",
      avatarFallback: .initials("AH"),
      presence: .online(responseSpeed: .fast),
      metrics: [
        .init(id: "rating", value: "4.9", label: "Rating"),
        .init(id: "rating", value: "5", label: "Duplicate"),
        .init(id: "reply", value: "2m", label: "Reply"),
        .init(id: "sales", value: "38", label: "Sales"),
        .init(id: "extra", value: "1", label: "Extra"),
      ]
    )
    check(
      metricsModel.metrics.map(\.id) == ["rating", "reply", "sales"],
      "metric IDs are unique and capped",
      failures: &failures
    )

    let nanOrder = SpearOrderContext(
      id: "nan",
      eyebrow: "Order",
      title: "Order",
      detail: "Preparing",
      actionTitle: "Track",
      progress: .nan
    )
    check(nanOrder.progress == nil, "NaN order progress is rejected", failures: &failures)

    let futureOfflineText = SpearChatHeaderCopy.english.presenceText(
      for: .offline(lastActiveAt: Date().addingTimeInterval(60 * 60))
    )
    check(
      !futureOfflineText.contains("in 1 hour"),
      "future offline timestamp is clamped",
      failures: &failures
    )

    var didEnd = false
    let activeCall = SpearCallControl.active(elapsedSeconds: -1) { didEnd = true }
    activeCall.buttonAction.perform()
    check(
      activeCall.isActive && activeCall.elapsedSeconds == 0 && didEnd,
      "active call owns a working end action",
      failures: &failures
    )

    if failures.isEmpty {
      print("All Foundation runtime contracts passed.")
      return
    }

    for failure in failures {
      fputs("FAIL: \(failure)\n", stderr)
    }
    exit(1)
  }

  private static func check(
    _ condition: @autoclosure () -> Bool,
    _ name: String,
    failures: inout [String]
  ) {
    if condition() {
      print("PASS: \(name)")
    } else {
      failures.append(name)
    }
  }
}
