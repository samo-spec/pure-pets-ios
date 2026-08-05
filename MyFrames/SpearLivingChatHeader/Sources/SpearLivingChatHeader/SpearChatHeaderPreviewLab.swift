#if DEBUG
  import SwiftUI

  @available(iOS 17.0, *)
  struct SpearChatHeaderPreviewLab: View {
    private enum LoadMode: String, CaseIterable, Identifiable {
      case ready = "Ready"
      case loading = "Loading"
      case unavailable = "Error"

      var id: Self { self }
    }

    private enum PresenceMode: String, CaseIterable, Identifiable {
      case online = "Online"
      case typing = "Typing"
      case viewing = "Viewing"
      case offline = "Offline"
      case call = "Call"

      var id: Self { self }
    }

    private enum TrustMode: String, CaseIterable, Identifiable {
      case standard = "Standard"
      case seller = "Seller"
      case business = "Business"
      case restricted = "Restricted"

      var id: Self { self }
    }

    private enum ContextMode: String, CaseIterable, Identifiable {
      case none = "None"
      case listing = "Listing"
      case order = "Order"
      case support = "Support"

      var id: Self { self }
    }

    private enum TextSizeMode: String, CaseIterable, Identifiable {
      case standard = "Standard"
      case large = "Large"
      case accessibility = "AX 3"

      var id: Self { self }

      var value: DynamicTypeSize {
        switch self {
        case .standard:
          .large
        case .large:
          .xxxLarge
        case .accessibility:
          .accessibility3
        }
      }
    }

    @State private var loadMode: LoadMode = .ready
    @State private var presenceMode: PresenceMode = .online
    @State private var trustMode: TrustMode = .seller
    @State private var contextMode: ContextMode = .listing
    @State private var textSizeMode: TextSizeMode = .standard
    @State private var isRTL = false
    @State private var phoneWidth = 390.0
    @State private var callElapsedSeconds = 138
    @State private var draft = ""
    @State private var toast: String?
    @State private var messages = DemoMessage.samples

    private let brandColor = Color(
      red: 203.0 / 255.0,
      green: 38.0 / 255.0,
      blue: 84.0 / 255.0
    )

    var body: some View {
      ScrollView {
        VStack(spacing: 18) {
          controls
          phonePreview
        }
        .padding(16)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .task(id: presenceMode) {
        guard presenceMode == .call else { return }

        while !Task.isCancelled && presenceMode == .call {
          try? await Task.sleep(for: .seconds(1))
          guard !Task.isCancelled else { return }
          callElapsedSeconds += 1
        }
      }
    }

    private var controls: some View {
      VStack(alignment: .leading, spacing: 14) {
        Text("Release Preview Lab")
          .font(.headline)

        controlPicker("State", selection: $loadMode)
        controlPicker("Presence", selection: $presenceMode)
        controlPicker("Trust", selection: $trustMode)
        controlPicker("Context", selection: $contextMode)
        controlPicker("Type", selection: $textSizeMode)

        Picker("Width", selection: $phoneWidth) {
          Text("320").tag(320.0)
          Text("390").tag(390.0)
          Text("430").tag(430.0)
        }
        .pickerStyle(.segmented)

        Toggle("Arabic RTL", isOn: $isRTL)
      }
      .padding(16)
      .background(
        Color(uiColor: .secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
      )
    }

    private func controlPicker<
      Selection: Hashable & CaseIterable & Identifiable & RawRepresentable
    >(
      _ title: String,
      selection: Binding<Selection>
    ) -> some View where Selection.RawValue == String, Selection.AllCases: RandomAccessCollection {
      Picker(title, selection: selection) {
        ForEach(Selection.allCases) { item in
          Text(item.rawValue).tag(item)
        }
      }
      .pickerStyle(.segmented)
    }

    private var phonePreview: some View {
      VStack(spacing: 0) {
        statusBar
        chatBody
      }
      .frame(width: phoneWidth)
      .background(Color(uiColor: .systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.12))
      }
      .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
      .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
      .environment(\.dynamicTypeSize, textSizeMode.value)
    }

    private var statusBar: some View {
      HStack {
        Text(isRTL ? "٧:٥٨" : "7:58")
          .font(.caption.weight(.semibold))
        Spacer()
        Image(systemName: "cellularbars")
        Image(systemName: "wifi")
        Image(systemName: "battery.100")
      }
      .font(.caption2)
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 4)
    }

    private var chatBody: some View {
      VStack(spacing: 0) {
        SpearChatHeader(
          state: headerState,
          style: SpearChatHeaderStyle(brandColor: brandColor),
          copy: isRTL ? .arabic : .english,
          actions: headerActions
        )

        ScrollView {
          LazyVStack(spacing: 12) {
            Text(isRTL ? "اليوم، ٧:٢٤ ص" : "Today, 7:24 AM")
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.vertical, 4)

            ForEach(messages) { message in
              DemoMessageBubble(
                message: localized(message),
                brandColor: brandColor,
                isRTL: isRTL
              )
            }

            DemoProtectedOfferCard(
              isRTL: isRTL,
              brandColor: brandColor
            ) {
              showToast(isRTL ? "تم فتح العرض المحمي" : "Protected offer opened")
            }
          }
          .padding(14)
        }
        .frame(minHeight: 390)

        composer
      }
      .overlay(alignment: .bottom) {
        if let toast {
          Text(toast)
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.primary, in: Capsule())
            .padding(.bottom, 68)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.updatesFrequently)
        }
      }
    }

    private var composer: some View {
      HStack(alignment: .bottom, spacing: 8) {
        Button {
          showToast(isRTL ? "صور · موقع · إعلان · عرض" : "Photos · Location · Listing · Offer")
        } label: {
          Image(systemName: "plus")
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)

        TextField(
          isRTL ? "اكتب رسالة…" : "Message Ahmed…",
          text: $draft,
          axis: .vertical
        )
        .lineLimit(1...4)
        .textFieldStyle(.roundedBorder)
        .frame(minHeight: 44)

        Button(action: sendMessage) {
          Image(systemName: "arrow.up")
            .font(.body.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(brandColor, in: Circle())
        }
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        .accessibilityLabel(isRTL ? "إرسال" : "Send")
      }
      .padding(10)
      .background(.bar)
    }

    private var headerState: SpearChatHeaderLoadState {
      switch loadMode {
      case .loading:
        .loading
      case .unavailable:
        .unavailable(
          title: isRTL ? "تعذر تحميل بيانات المحادثة" : "Conversation details unavailable",
          retryTitle: isRTL ? "إعادة المحاولة" : "Retry"
        )
      case .ready:
        .ready(headerModel)
      }
    }

    private var headerModel: SpearChatHeaderModel {
      SpearChatHeaderModel(
        id: "ahmed-hassan",
        name: isRTL ? "أحمد حسن" : "Ahmed Hassan",
        avatarFallback: .initials(isRTL ? "أح" : "AH"),
        trust: trustState,
        presence: presence,
        metrics: metrics,
        context: context
      )
    }

    private var trustState: SpearTrustState {
      switch trustMode {
      case .standard:
        .standard(role: isRTL ? "عميل" : "Customer")
      case .seller:
        .verifiedSeller(
          role: isRTL ? "بائع" : "Seller",
          location: isRTL ? "القاهرة" : "Cairo"
        )
      case .business:
        .verifiedBusiness(displayName: isRTL ? "متجر SPEar المعتمد" : "SPEar Certified Store")
      case .restricted:
        .restricted(
          reason: isRTL ? "تم تقييد بعض ميزات الحساب" : "Some account features are restricted")
      }
    }

    private var presence: SpearPresence {
      switch presenceMode {
      case .online:
        .online(responseSpeed: .fast)
      case .typing:
        .typing
      case .viewing:
        .viewingOffer
      case .offline:
        .offline(lastActiveAt: Date().addingTimeInterval(-12 * 60))
      case .call:
        .online(responseSpeed: nil)
      }
    }

    private var metrics: [SpearIdentityMetric] {
      [
        .init(id: "rating", value: "4.9", label: isRTL ? "التقييم" : "Rating"),
        .init(
          id: "reply", value: isRTL ? "دقيقتان" : "2 min", label: isRTL ? "سرعة الرد" : "Reply time"
        ),
        .init(id: "sales", value: "38", label: isRTL ? "عملية بيع" : "Sales"),
      ]
    }

    private var context: SpearConversationContext? {
      switch contextMode {
      case .none:
        nil

      case .listing:
        .listing(
          SpearListingContext(
            id: "listing-2048",
            eyebrow: isRTL ? "تتحدثان عن هذا الإعلان" : "Discussing this listing",
            title: isRTL ? "جرو جولدن ريتريفر" : "Golden Retriever Puppy",
            detail: isRTL ? "٨٬٥٠٠ ج.م · متاح" : "EGP 8,500 · Available",
            actionTitle: isRTL ? "عرض" : "View"
          )
        )

      case .order:
        .order(
          SpearOrderContext(
            id: "order-2048",
            eyebrow: isRTL ? "طلب نشط · محمي من SPEar" : "Active order · SPEar protected",
            title: isRTL ? "الطلب SP-2048" : "Order SP-2048",
            detail: isRTL ? "البائع يجهز الطلب" : "Seller is preparing your order",
            actionTitle: isRTL ? "تتبع" : "Track",
            progress: 0.62
          )
        )

      case .support:
        .support(
          SpearSupportContext(
            id: "support-611",
            eyebrow: isRTL ? "حالة دعم نشطة" : "Active support case",
            title: isRTL ? "الحالة SP-611" : "Case SP-611",
            detail: isRTL ? "آخر تحديث منذ ٤ دقائق" : "Updated 4 minutes ago",
            actionTitle: isRTL ? "فتح" : "Open"
          )
        )
      }
    }

    private var headerActions: SpearChatHeaderActions {
      SpearChatHeaderActions(
        onBack: {
          showToast(isRTL ? "العودة إلى المحادثات" : "Back to conversations")
        },
        call: presenceMode == .call
          ? .active(elapsedSeconds: callElapsedSeconds, end: toggleCall)
          : .start(perform: toggleCall),
        more: .enabled {
          showToast(isRTL ? "الوسائط · البحث · الأمان" : "Media · Search · Safety")
        },
        profile: .enabled {
          showToast(isRTL ? "تم فتح ملف البائع" : "Seller profile opened")
        },
        safety: .enabled {
          showToast(isRTL ? "تم فتح أدوات الأمان" : "Safety tools opened")
        },
        context: .enabled { _ in
          showToast(isRTL ? "تم فتح سياق المحادثة" : "Conversation context opened")
        },
        retry: .enabled(retryLoading)
      )
    }

    private func localized(_ message: DemoMessage) -> DemoMessage {
      guard isRTL else { return message }

      switch message.id {
      case "question":
        return .init(
          id: message.id,
          text: "مرحبًا، هل الجرو ما زال متاحًا؟",
          time: "٧:٢٥",
          isMine: false
        )
      case "reply":
        return .init(
          id: message.id,
          text: "نعم، ما زال متاحًا. يمكنني إرسال تفاصيل التطعيمات.",
          time: "٧:٢٦ ✓✓",
          isMine: true
        )
      default:
        return message
      }
    }

    private func toggleCall() {
      if presenceMode == .call {
        presenceMode = .online
        showToast(isRTL ? "تم إنهاء المكالمة" : "Call ended")
      } else {
        callElapsedSeconds = 0
        presenceMode = .call
        showToast(isRTL ? "بدأت مكالمة SPEar الآمنة" : "Secure SPEar call started")
      }
    }

    private func retryLoading() {
      loadMode = .loading
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(850))
        loadMode = .ready
        showToast(isRTL ? "تم تحديث المحادثة" : "Conversation refreshed")
      }
    }

    private func sendMessage() {
      let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return }

      withAnimation(.snappy(duration: 0.3, extraBounce: 0.05)) {
        messages.append(
          DemoMessage(
            id: UUID().uuidString,
            text: text,
            time: isRTL ? "الآن ✓" : "Now ✓",
            isMine: true
          )
        )
        draft = ""
        presenceMode = .viewing
      }

      showToast(isRTL ? "تم إرسال الرسالة" : "Message sent")
    }

    private func showToast(_ value: String) {
      withAnimation(.snappy(duration: 0.24)) {
        toast = value
      }

      Task { @MainActor in
        try? await Task.sleep(for: .seconds(1.6))
        guard toast == value else { return }
        withAnimation(.easeOut(duration: 0.2)) {
          toast = nil
        }
      }
    }
  }

  private struct DemoMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let time: String
    let isMine: Bool

    static let samples: [DemoMessage] = [
      .init(id: "question", text: "Hi! Is the puppy still available?", time: "7:25", isMine: false),
      .init(
        id: "reply",
        text: "Yes, he is available. I can send you the vaccination details.",
        time: "7:26 ✓✓",
        isMine: true
      ),
    ]
  }

  private struct DemoMessageBubble: View {
    let message: DemoMessage
    let brandColor: Color
    let isRTL: Bool

    var body: some View {
      HStack {
        if message.isMine { Spacer(minLength: 48) }

        VStack(alignment: .trailing, spacing: 4) {
          Text(message.text)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(message.time)
            .font(.caption2)
            .foregroundStyle(message.isMine ? .white.opacity(0.72) : .secondary)
        }
        .font(.subheadline)
        .foregroundStyle(message.isMine ? .white : .primary)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
          message.isMine ? brandColor : Color(uiColor: .secondarySystemBackground),
          in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )

        if !message.isMine { Spacer(minLength: 48) }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        message.isMine
          ? (isRTL ? "أنت: \(message.text)" : "You: \(message.text)")
          : (isRTL ? "أحمد: \(message.text)" : "Ahmed: \(message.text)")
      )
    }
  }

  private struct DemoProtectedOfferCard: View {
    let isRTL: Bool
    let brandColor: Color
    let action: () -> Void

    var body: some View {
      HStack(spacing: 10) {
        Image(systemName: "shield.checkered")
          .font(.body.weight(.semibold))
          .foregroundStyle(brandColor)
          .frame(width: 44, height: 44)
          .background(
            brandColor.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(isRTL ? "عرض SPEar محمي" : "Protected SPEar offer")
            .font(.subheadline.weight(.semibold))
          Text(isRTL ? "٨٬٠٠٠ ج.م · صالح لمدة ٢٤ ساعة" : "EGP 8,000 · Valid for 24 hours")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button(isRTL ? "مراجعة" : "Review", action: action)
          .font(.caption.weight(.semibold))
          .buttonStyle(.bordered)
          .buttonBorderShape(.roundedRectangle(radius: 11))
          .frame(minHeight: 44)
      }
      .padding(12)
      .background(
        Color(uiColor: .secondarySystemBackground),
        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
      )
    }
  }

  @available(iOS 17.0, *)
  #Preview("Release Lab") {
    SpearChatHeaderPreviewLab()
  }

  @available(iOS 17.0, *)
  #Preview("320 · RTL · AX3") {
    SpearChatHeaderPreviewLab()
      .environment(\.layoutDirection, .rightToLeft)
      .environment(\.dynamicTypeSize, .accessibility3)
  }
#endif
