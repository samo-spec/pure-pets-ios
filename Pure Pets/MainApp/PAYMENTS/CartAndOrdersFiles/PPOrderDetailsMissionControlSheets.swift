//
//  PPOrderDetailsMissionControlSheets.swift
//  Pure Pets
//

import PhotosUI
import SwiftUI

@available(iOS 17.0, *)
struct PPOrderMissionSheetRoot: View {
    let sheet: PPOrderMissionSheet
    @ObservedObject var store: PPOrderDetailsMissionControlStore

    var body: some View {
        Group {
            switch sheet {
            case .timeline:
                PPOrderMissionTimelineSheet(store: store)
            case .requests:
                PPOrderMissionRequestsSheet(store: store)
            case let .request(request):
                PPOrderMissionRequestDetailsSheet(
                    request: request,
                    store: store
                )
            case .support:
                PPOrderMissionSupportSheet(store: store)
            case let .composer(action):
                PPOrderMissionComposerSheet(action: action, store: store)
            case .addresses:
                PPOrderMissionAddressesSheet(store: store)
            case let .fulfillment(fulfillment):
                PPOrderMissionFulfillmentSheet(
                    fulfillment: fulfillment,
                    store: store
                )
            }
        }
        .environment(
            \.layoutDirection,
            store.isRightToLeft ? .rightToLeft : .leftToRight
        )
        .environment(\.locale, Locale(identifier: store.languageCode))
        .alert(item: sheetNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text(PPOrderMissionText("OK")))
            )
        }
    }

    private var sheetNotice: Binding<PPOrderMissionNotice?> {
        Binding(
            get: { store.activeSheet == nil ? nil : store.notice },
            set: { newValue in
                if newValue == nil { store.notice = nil }
            }
        )
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionTimelineSheet: View {
    @ObservedObject var store: PPOrderDetailsMissionControlStore
    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        Color(uiColor: store.state.statusColor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if store.state.timelineLoading &&
                        store.state.timeline.isEmpty {
                        ProgressView()
                            .tint(accent)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .accessibilityLabel(PPOrderMissionText("Loading"))
                    } else if !store.state.timelineErrorMessage.isEmpty &&
                                store.state.timeline.isEmpty {
                        PPOrderMissionSheetEmptyState(
                            symbol: "wifi.exclamationmark",
                            title: store.state.timelineErrorMessage,
                            actionTitle: PPOrderMissionText("KLang_Retry"),
                            action: store.refresh
                        )
                    } else if store.state.timeline.isEmpty {
                        PPOrderMissionSheetEmptyState(
                            symbol: "clock.arrow.circlepath",
                            title: PPOrderMissionText(
                                "order_tracking_empty_subtitle"
                            ),
                            actionTitle: PPOrderMissionText("KLang_Retry"),
                            action: store.refresh
                        )
                    } else {
                        if !store.state.timelineErrorMessage.isEmpty {
                            PPOrderMissionInlineNotice(
                                symbol: "wifi.exclamationmark",
                                text: store.state.timelineErrorMessage,
                                color: Color.ppWarning
                            )
                            .padding(.bottom, PPSpace.base)
                        }
                        ForEach(
                            Array(store.state.timeline.enumerated()),
                            id: \.element.id
                        ) { index, event in
                            PPOrderMissionTimelineRow(
                                event: event,
                                accent: accent,
                                isLast: index == store.state.timeline.count - 1
                            )
                        }
                    }
                }
                .padding(PPSpace.base)
            }
            .background(Color.ppBackground)
            .navigationTitle(PPOrderMissionText("order_tracking_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("Done")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionRequestsSheet: View {
    @ObservedObject var store: PPOrderDetailsMissionControlStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: PPSpace.md) {
                    if store.state.supportLoading &&
                        store.state.requests.isEmpty {
                        ProgressView()
                            .tint(Color.ppPrimary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .accessibilityLabel(PPOrderMissionText("Loading"))
                    } else if !store.state.supportErrorMessage.isEmpty &&
                                store.state.requests.isEmpty {
                        PPOrderMissionSheetEmptyState(
                            symbol: "wifi.exclamationmark",
                            title: store.state.supportErrorMessage,
                            actionTitle: PPOrderMissionText("KLang_Retry"),
                            action: store.refresh
                        )
                    } else if store.state.requests.isEmpty {
                        PPOrderMissionSheetEmptyState(
                            symbol: "tray",
                            title: PPOrderMissionText(
                                "order_requests_empty_title"
                            ),
                            subtitle: PPOrderMissionText(
                                "order_requests_empty_subtitle"
                            ),
                            actionTitle: PPOrderMissionText(
                                "order_action_support_case"
                            )
                        ) {
                            store.presentSupportComposer()
                        }
                    } else {
                        if !store.state.supportErrorMessage.isEmpty {
                            PPOrderMissionInlineNotice(
                                symbol: "wifi.exclamationmark",
                                text: store.state.supportErrorMessage,
                                color: Color.ppWarning
                            )
                        }
                        ForEach(store.state.requests) { request in
                            Button {
                                store.presentRequest(request)
                            } label: {
                                PPOrderMissionRequestCard(request: request)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(PPSpace.base)
            }
            .background(Color.ppBackground)
            .navigationTitle(
                PPOrderMissionText("order_requests_history_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.presentSupportComposer()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(
                        PPOrderMissionText("order_action_support_case")
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("Done")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionRequestDetailsSheet: View {
    let request: PPOrderMissionRequest
    @ObservedObject var store: PPOrderDetailsMissionControlStore
    @Environment(\.dismiss) private var dismiss

    private var currentRequest: PPOrderMissionRequest {
        store.state.requests.first {
            $0.requestID == request.requestID
        } ?? request
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    requestHero

                    if !currentRequest.notes.isEmpty {
                        detailsSection(
                            title: PPOrderMissionText(
                                "order_request_notes_title"
                            ),
                            symbol: "text.alignleft"
                        ) {
                            Text(currentRequest.notes)
                                .font(PPOrderMissionTypography.body())
                                .foregroundStyle(Color.ppTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !currentRequest.itemSnapshots.isEmpty ||
                        !currentRequest.itemIDs.isEmpty {
                        detailsSection(
                            title: PPOrderMissionText(
                                "order_request_items_title"
                            ),
                            symbol: "shippingbox"
                        ) {
                            if !currentRequest.itemSnapshots.isEmpty {
                                ForEach(
                                    Array(
                                        currentRequest.itemSnapshots.enumerated()
                                    ),
                                    id: \.offset
                                ) { _, item in
                                    HStack(spacing: PPSpace.sm) {
                                        Label(
                                            item.name.isEmpty
                                                ? item.itemID
                                                : item.name,
                                            systemImage: "shippingbox"
                                        )
                                        .font(PPOrderMissionTypography.callout())
                                        .foregroundStyle(Color.ppTextPrimary)
                                        Spacer(minLength: PPSpace.sm)
                                        Text(
                                            String(
                                                format: PPOrderMissionText(
                                                    "order_mission_quantity_format"
                                                ),
                                                item.quantity
                                            )
                                        )
                                        .font(PPOrderMissionTypography.caption())
                                        .foregroundStyle(Color.ppTextSecondary)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            } else {
                                ForEach(currentRequest.itemIDs, id: \.self) { itemID in
                                    Label(itemID, systemImage: "circle.fill")
                                        .font(PPOrderMissionTypography.callout())
                                        .foregroundStyle(Color.ppTextSecondary)
                                        .environment(\.layoutDirection, .leftToRight)
                                }
                            }
                        }
                    }

                    if currentRequest.type == "cancel" ||
                        !currentRequest.cancellationDisposition.isEmpty {
                        detailsSection(
                            title: PPOrderMissionText(
                                "order_mission_cancellation_outcome"
                            ),
                            symbol: currentRequest.orderCancelled
                                ? "checkmark.shield"
                                : "clock.badge.questionmark"
                        ) {
                            Text(cancellationOutcomeText)
                                .font(PPOrderMissionTypography.body())
                                .foregroundStyle(Color.ppTextPrimary)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                        }
                    }

                    if !currentRequest.attachments.isEmpty {
                        detailsSection(
                            title: PPOrderMissionText(
                                "order_request_attachments_title"
                            ),
                            symbol: "photo.on.rectangle.angled"
                        ) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: PPSpace.sm) {
                                    ForEach(currentRequest.attachments) { attachment in
                                        AppRemoteImage(
                                            urlString: attachment.url,
                                            cacheKey: attachment.url,
                                            displaySize: CGSize(
                                                width: 116,
                                                height: 116
                                            ),
                                            contentMode: .fill
                                        )
                                        .frame(width: 116, height: 116)
                                        .clipShape(
                                            RoundedRectangle(
                                                cornerRadius: PPCorner.small,
                                                style: .continuous
                                            )
                                        )
                                        .accessibilityLabel(
                                            attachment.fileName
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if !currentRequest.adminReviewSummary.isEmpty {
                        detailsSection(
                            title: PPOrderMissionText(
                                "order_mission_admin_review"
                            ),
                            symbol: "person.badge.shield.checkmark"
                        ) {
                            Text(currentRequest.adminReviewSummary)
                                .font(PPOrderMissionTypography.body())
                                .foregroundStyle(Color.ppTextPrimary)
                        }
                    }

                    if !currentRequest.resolutionSummary.isEmpty ||
                        !currentRequest.finalResolution.isEmpty {
                        detailsSection(
                            title: PPOrderMissionText(
                                "order_mission_resolution"
                            ),
                            symbol: "checkmark.seal"
                        ) {
                            Text(
                                currentRequest.resolutionSummary.isEmpty
                                    ? currentRequest.finalResolution
                                    : currentRequest.resolutionSummary
                            )
                            .font(PPOrderMissionTypography.body())
                            .foregroundStyle(Color.ppTextPrimary)
                        }
                    }

                    detailsSection(
                        title: PPOrderMissionText(
                            "order_request_timeline_title"
                        ),
                        symbol: "clock.arrow.circlepath"
                    ) {
                        if store.requestEventsLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .tint(Color.ppPrimary)
                        } else if !store.requestEventsError.isEmpty {
                            VStack(spacing: PPSpace.sm) {
                                PPOrderMissionInlineNotice(
                                    symbol: "wifi.exclamationmark",
                                    text: store.requestEventsError,
                                    color: Color.ppWarning
                                )
                                Button(action: store.retryRequestEvents) {
                                    Label(
                                        PPOrderMissionText("KLang_Retry"),
                                        systemImage: "arrow.clockwise"
                                    )
                                    .font(PPOrderMissionTypography.callout())
                                    .foregroundStyle(Color.ppPrimary)
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: 44
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else if store.requestEvents.isEmpty {
                            PPOrderMissionInlineEmpty(
                                symbol: "clock",
                                title: PPOrderMissionText(
                                    "fulfillment_no_events"
                                )
                            )
                        } else {
                            ForEach(
                                Array(store.requestEvents.enumerated()),
                                id: \.element.id
                            ) { index, event in
                                PPOrderMissionTimelineRow(
                                    event: event,
                                    accent: Color.ppPrimary,
                                    isLast: index == store.requestEvents.count - 1
                                )
                            }
                        }
                    }
                }
                .padding(PPSpace.base)
            }
            .background(Color.ppBackground)
            .navigationTitle(
                PPOrderMissionText("order_mission_request_details")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("Done")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.large])
    }

    private var requestHero: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 52, height: 52)
                    .background(Color.ppPrimary.opacity(0.11), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentRequest.typeTitle)
                        .font(PPOrderMissionTypography.title())
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(currentRequest.reasonTitle)
                        .font(PPOrderMissionTypography.body())
                        .foregroundStyle(Color.ppTextSecondary)
                }
                Spacer(minLength: 0)
            }

            HStack {
                PPOrderMissionStatusChip(
                    title: currentRequest.statusTitle,
                    color: Color.ppPrimary
                )
                Spacer()
                Text(currentRequest.createdAtText)
                    .font(PPOrderMissionTypography.caption())
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .padding(PPSpace.lg)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary, emphasis: true))
        .accessibilityElement(children: .combine)
    }

    private var cancellationOutcomeText: String {
        if currentRequest.orderCancelled {
            return PPOrderMissionText("OrderCanceled")
        }
        switch currentRequest.cancellationDisposition {
        case "cancelled", "legacy_cancelled":
            return PPOrderMissionText("OrderCanceled")
        case "pending_review", "blocked_by_child_state",
             "blocked_by_compensation_state":
            return PPOrderMissionText(
                "order_mission_cancellation_pending_review"
            )
        case "existing_request":
            return PPOrderMissionText("order_existing_request_opened")
        default:
            return currentRequest.statusTitle
        }
    }

    private func detailsSection<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Label(title, systemImage: symbol)
                .font(PPOrderMissionTypography.headline())
                .foregroundStyle(Color.ppTextPrimary)
            content()
        }
        .padding(PPSpace.base)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary))
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionSupportSheet: View {
    @ObservedObject var store: PPOrderDetailsMissionControlStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PPSpace.md) {
                    PPOrderMissionSupportOption(
                        title: PPOrderMissionText("order_action_support_case"),
                        subtitle: PPOrderMissionText("order_action_support_hint"),
                        symbol: "square.and.pencil",
                        action: store.presentSupportComposer
                    )
                    PPOrderMissionSupportOption(
                        title: PPOrderMissionText("cart_support_chat"),
                        subtitle: PPOrderMissionText(
                            "order_mission_support_chat_hint"
                        ),
                        symbol: "message",
                        action: store.chatWithSupport
                    )
                    PPOrderMissionSupportOption(
                        title: PPOrderMissionText("order_support_request_call"),
                        subtitle: PPOrderMissionText(
                            "order_mission_support_call_hint"
                        ),
                        symbol: "phone",
                        action: store.callSupport
                    )
                }
                .padding(PPSpace.base)
            }
            .background(Color.ppBackground)
            .navigationTitle(
                PPOrderMissionText("cart_support_menu_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("Done")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionComposerSheet: View {
    let action: PPOrderMissionAction
    @ObservedObject var store: PPOrderDetailsMissionControlStore

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: PPOrderMissionReason?
    @State private var notes = ""
    @State private var selectedItemIDs: Set<String> = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var isLoadingImages = false

    private var reasons: [PPOrderMissionReason] {
        store.reasons(for: action)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.lg) {
                    PPOrderMissionComposerIntro(action: action)

                    formSection(
                        title: PPOrderMissionText(
                            "order_request_reason_title"
                        ),
                        symbol: "list.bullet.rectangle"
                    ) {
                        if reasons.isEmpty {
                            Text(PPOrderMissionText("order_reason_other_title"))
                                .font(PPOrderMissionTypography.body())
                                .foregroundStyle(Color.ppTextSecondary)
                        } else {
                            VStack(spacing: PPSpace.sm) {
                                ForEach(reasons) { reason in
                                    Button {
                                        selectedReason = reason
                                        if !reason.requiresItemSelection {
                                            selectedItemIDs.removeAll()
                                        }
                                    } label: {
                                        PPOrderMissionReasonRow(
                                            reason: reason,
                                            isSelected: reason == selectedReason
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if selectedReason?.requiresItemSelection == true {
                        formSection(
                            title: PPOrderMissionText(
                                "order_request_items_title"
                            ),
                            symbol: "shippingbox"
                        ) {
                            if store.state.items.isEmpty {
                                PPOrderMissionInlineEmpty(
                                    symbol: "shippingbox",
                                    title: PPOrderMissionText(
                                        "order_details_no_items"
                                    )
                                )
                            } else {
                                ForEach(store.state.items) { item in
                                    Button {
                                        if selectedItemIDs.contains(item.itemID) {
                                            selectedItemIDs.remove(item.itemID)
                                        } else if !item.itemID.isEmpty {
                                            selectedItemIDs.insert(item.itemID)
                                        }
                                    } label: {
                                        PPOrderMissionSelectableItemRow(
                                            item: item,
                                            isSelected: selectedItemIDs.contains(
                                                item.itemID
                                            )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(item.itemID.isEmpty)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    formSection(
                        title: PPOrderMissionText(
                            "order_request_notes_title"
                        ),
                        symbol: "text.alignleft"
                    ) {
                        TextEditor(text: $notes)
                            .font(PPOrderMissionTypography.body())
                            .frame(minHeight: 116)
                            .scrollContentBackground(.hidden)
                            .padding(PPSpace.sm)
                            .background(
                                Color.ppSecondarySurface,
                                in: RoundedRectangle(
                                    cornerRadius: PPCorner.small,
                                    style: .continuous
                                )
                            )
                            .accessibilityLabel(
                                PPOrderMissionText(
                                    "order_request_notes_title"
                                )
                            )
                    }

                    formSection(
                        title: PPOrderMissionText(
                            "order_request_attachments_title"
                        ),
                        symbol: "photo.on.rectangle.angled"
                    ) {
                        Text(
                            PPOrderMissionText(
                                "order_request_photos_optional"
                            )
                        )
                        .font(PPOrderMissionTypography.callout())
                        .foregroundStyle(Color.ppTextSecondary)

                        if !images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: PPSpace.sm) {
                                    ForEach(Array(images.enumerated()), id: \.offset) {
                                        index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 96, height: 96)
                                                .clipShape(
                                                    RoundedRectangle(
                                                        cornerRadius: PPCorner.small,
                                                        style: .continuous
                                                    )
                                                )
                                            Button {
                                                images.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(Color.white)
                                                    .frame(width: 28, height: 28)
                                                    .background(Color.black.opacity(0.7), in: Circle())
                                                    .frame(width: 44, height: 44)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .offset(x: 6, y: -6)
                                            .accessibilityLabel(
                                                PPOrderMissionText(
                                                    "order_mission_remove_photo"
                                                )
                                            )
                                        }
                                    }
                                }
                                .padding(.top, PPSpace.sm)
                            }
                        }

                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: max(1, 4 - images.count),
                            matching: .images
                        ) {
                            Label(
                                PPOrderMissionText("order_request_add_photos"),
                                systemImage: "plus"
                            )
                            .font(PPOrderMissionTypography.callout())
                            .foregroundStyle(Color.ppPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                Color.ppPrimary.opacity(0.09),
                                in: RoundedRectangle(
                                    cornerRadius: PPCorner.small,
                                    style: .continuous
                                )
                            )
                        }
                        .disabled(images.count >= 4 || isLoadingImages)
                        .onChange(of: pickerItems) { _, newItems in
                            loadImages(newItems)
                        }
                    }

                    Button(action: submit) {
                        HStack(spacing: PPSpace.sm) {
                            if store.isCommandRunning {
                                ProgressView().tint(Color.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                            }
                            Text(
                                PPOrderMissionText(
                                    store.isCommandRunning
                                        ? "order_request_submitting"
                                        : "order_request_submit"
                                )
                            )
                        }
                        .font(PPOrderMissionTypography.headline())
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(PPGradient.hero)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: PPCorner.medium,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit || store.isCommandRunning)
                    .opacity(canSubmit ? 1 : 0.58)
                }
                .padding(PPSpace.base)
            }
            .background(Color.ppBackground)
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("cancel")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.large])
    }

    private var canSubmit: Bool {
        let hasReason = reasons.isEmpty || selectedReason != nil
        let hasItems = selectedReason?.requiresItemSelection != true ||
            !selectedItemIDs.isEmpty
        return hasReason && hasItems && !isLoadingImages
    }

    private func submit() {
        store.submit(
            action: action,
            reason: selectedReason,
            notes: notes,
            selectedItemIDs: selectedItemIDs,
            images: images
        )
    }

    private func loadImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoadingImages = true
        Task {
            var loaded: [UIImage] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }
                loaded.append(image)
            }
            await MainActor.run {
                images = Array((images + loaded).prefix(4))
                pickerItems = []
                isLoadingImages = false
            }
        }
    }

    private func formSection<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            Label(title, systemImage: symbol)
                .font(PPOrderMissionTypography.headline())
                .foregroundStyle(Color.ppTextPrimary)
            content()
        }
        .padding(PPSpace.base)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary))
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionAddressesSheet: View {
    @ObservedObject var store: PPOrderDetailsMissionControlStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: PPSpace.md) {
                    if store.addressesLoading {
                        ProgressView(PPOrderMissionText("Loading"))
                            .font(PPOrderMissionTypography.body())
                            .tint(Color.ppPrimary)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if !store.addressesError.isEmpty {
                        PPOrderMissionSheetEmptyState(
                            symbol: "wifi.exclamationmark",
                            title: PPOrderMissionText("addr_empty_title"),
                            subtitle: store.addressesError,
                            actionTitle: PPOrderMissionText("KLang_Retry"),
                            action: store.presentAddresses
                        )
                    } else if store.addresses.isEmpty {
                        PPOrderMissionSheetEmptyState(
                            symbol: "house.badge.plus",
                            title: PPOrderMissionText("addr_empty_title"),
                            subtitle: PPOrderMissionText("addr_empty_subtitle"),
                            actionTitle: PPOrderMissionText("addr_empty_btn_add"),
                            action: store.addAddress
                        )
                    } else {
                        ForEach(store.addresses) { address in
                            Button {
                                store.selectAddress(address)
                            } label: {
                                PPOrderMissionAddressRow(address: address)
                            }
                            .buttonStyle(.plain)
                            .disabled(
                                store.isCommandRunning || !address.isSelectable
                            )
                            .accessibilityValue(
                                address.isSelectable
                                    ? PPOrderMissionText(
                                        "order_mission_available"
                                    )
                                    : address.availabilityMessage
                            )
                        }

                        Button(action: store.addAddress) {
                            Label(
                                PPOrderMissionText("addr_empty_btn_add"),
                                systemImage: "plus"
                            )
                            .font(PPOrderMissionTypography.callout())
                            .foregroundStyle(Color.ppPrimary)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                Color.ppPrimary.opacity(0.09),
                                in: RoundedRectangle(
                                    cornerRadius: PPCorner.medium,
                                    style: .continuous
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PPSpace.base)
            }
            .background(Color.ppBackground)
            .navigationTitle(
                PPOrderMissionText("Select Delivery Location")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("Done")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

@available(iOS 17.0, *)
private struct PPOrderMissionFulfillmentSheet: View {
    let fulfillment: PPOrderMissionFulfillment
    @ObservedObject var store: PPOrderDetailsMissionControlStore
    @Environment(\.dismiss) private var dismiss

    private var currentFulfillment: PPOrderMissionFulfillment? {
        if let current = store.state.fulfillments.first(
            where: { $0.id == fulfillment.id }
        ) {
            return current
        }
        return store.state.isInitialLoading || store.state.fulfillmentLoading
            ? fulfillment
            : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let currentFulfillment {
                    let color = Color(uiColor: currentFulfillment.statusColor)
                    VStack(alignment: .leading, spacing: PPSpace.lg) {
                        HStack(alignment: .top) {
                            Text(String(format: "%02d", currentFulfillment.sequence))
                                .font(PPOrderMissionTypography.title(28))
                                .foregroundStyle(color)
                                .environment(\.layoutDirection, .leftToRight)
                            Spacer()
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(color)
                                .frame(width: 54, height: 54)
                                .background(color.opacity(0.11), in: Circle())
                                .accessibilityHidden(true)
                        }
                        Text(currentFulfillment.ownerTitle)
                            .font(PPOrderMissionTypography.display(30))
                            .foregroundStyle(Color.ppTextPrimary)
                        PPOrderMissionStatusChip(
                            title: currentFulfillment.statusTitle,
                            color: color
                        )
                    }
                    .padding(PPSpace.xl)
                    .modifier(PPOrderMissionGlassCard(accent: color, emphasis: true))

                    VStack(spacing: PPSpace.md) {
                        PPOrderMissionSheetKeyValue(
                            key: PPOrderMissionText("fulfillment_items_count_label"),
                            value: currentFulfillment.itemCountText
                        )
                        Divider().overlay(Color.ppSeparator)
                        PPOrderMissionSheetKeyValue(
                            key: PPOrderMissionText("order_subtotal_label"),
                            value: currentFulfillment.subtotalText,
                            emphasized: true,
                            forceLeftToRight: true
                        )
                    }
                    .padding(PPSpace.base)
                    .modifier(PPOrderMissionGlassCard(accent: color))

                    PPOrderMissionInlineNotice(
                        symbol: "shield.checkered",
                        text: PPOrderMissionText(
                            "order_mission_fulfillment_authority_note"
                        ),
                        color: color
                    )
                    .padding(PPSpace.base)
                } else {
                    PPOrderMissionSheetEmptyState(
                        symbol: "square.3.layers.3d.slash",
                        title: PPOrderMissionText(
                            "fulfillment_not_available"
                        ),
                        actionTitle: PPOrderMissionText("KLang_Retry"),
                        action: store.refresh
                    )
                    .padding(PPSpace.base)
                }
            }
            .background(Color.ppBackground)
            .navigationTitle(
                PPOrderMissionText("order_mission_fulfillment_details")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(PPOrderMissionText("Done")) { dismiss() }
                        .font(PPOrderMissionTypography.callout())
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PPOrderMissionRequestCard: View {
    let request: PPOrderMissionRequest

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.ppPrimary.opacity(0.1), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.typeTitle)
                        .font(PPOrderMissionTypography.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(request.reasonTitle)
                        .font(PPOrderMissionTypography.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: PPSpace.sm)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
            }
            HStack {
                PPOrderMissionStatusChip(
                    title: request.statusTitle,
                    color: Color.ppPrimary
                )
                Spacer()
                Text(request.createdAtText)
                    .font(PPOrderMissionTypography.caption())
                    .foregroundStyle(Color.ppTextTertiary)
            }
        }
        .padding(PPSpace.base)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary))
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionSupportOption: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PPSpace.md) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
                    .frame(width: 46, height: 46)
                    .background(Color.ppPrimary.opacity(0.1), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PPOrderMissionTypography.headline())
                        .foregroundStyle(Color.ppTextPrimary)
                    Text(subtitle)
                        .font(PPOrderMissionTypography.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: PPSpace.sm)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.ppPrimary)
            }
            .padding(PPSpace.base)
            .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary))
        }
        .buttonStyle(.plain)
    }
}

private struct PPOrderMissionComposerIntro: View {
    let action: PPOrderMissionAction

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: action.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 52, height: 52)
                .background(Color.ppPrimary.opacity(0.1), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(action.title)
                    .font(PPOrderMissionTypography.title())
                    .foregroundStyle(Color.ppTextPrimary)
                Text(action.message)
                    .font(PPOrderMissionTypography.body())
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PPSpace.lg)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary, emphasis: true))
    }
}

private struct PPOrderMissionReasonRow: View {
    let reason: PPOrderMissionReason
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? Color.ppPrimary : Color.ppTextTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(reason.title)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                if !reason.subtitle.isEmpty {
                    Text(reason.subtitle)
                        .font(PPOrderMissionTypography.caption())
                        .foregroundStyle(Color.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .background(
            isSelected
                ? Color.ppPrimary.opacity(0.08)
                : Color.ppSecondarySurface.opacity(0.72),
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous)
                .stroke(
                    isSelected
                        ? Color.ppPrimary.opacity(0.38)
                        : Color.ppSurfaceBorder,
                    lineWidth: isSelected ? 1.2 : 0.7
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PPOrderMissionSelectableItemRow: View {
    let item: PPOrderMissionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? Color.ppPrimary : Color.ppTextTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(PPOrderMissionTypography.callout())
                    .foregroundStyle(Color.ppTextPrimary)
                Text(
                    String(
                        format: PPOrderMissionText(
                            "order_mission_quantity_format"
                        ),
                        item.quantity
                    )
                )
                .font(PPOrderMissionTypography.caption())
                .foregroundStyle(Color.ppTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(PPSpace.md)
        .background(
            Color.ppSecondarySurface,
            in: RoundedRectangle(
                cornerRadius: PPCorner.small,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PPOrderMissionAddressRow: View {
    let address: PPOrderMissionAddress

    var body: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: address.isSelected ? "mappin.circle.fill" : "mappin.circle")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.ppPrimary)
                .frame(width: 44, height: 44)
                .background(Color.ppPrimary.opacity(0.09), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(address.title)
                    .font(PPOrderMissionTypography.headline())
                    .foregroundStyle(Color.ppTextPrimary)
                if !address.subtitle.isEmpty && address.subtitle != address.title {
                    Text(address.subtitle)
                        .font(PPOrderMissionTypography.callout())
                        .foregroundStyle(Color.ppTextSecondary)
                        .lineLimit(2)
                }
                if address.isDefault {
                    Text(PPOrderMissionText("Default"))
                        .font(PPOrderMissionTypography.caption())
                        .foregroundStyle(Color.ppPrimary)
                }
                if !address.isSelectable {
                    Text(address.availabilityMessage)
                        .font(PPOrderMissionTypography.caption())
                        .foregroundStyle(Color.ppWarning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if address.isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.ppSuccess)
                    .accessibilityHidden(true)
            }
        }
        .padding(PPSpace.base)
        .modifier(PPOrderMissionGlassCard(accent: Color.ppPrimary))
        .opacity(address.isSelectable ? 1 : 0.68)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(address.isSelected ? .isSelected : [])
    }
}

private struct PPOrderMissionSheetKeyValue: View {
    let key: String
    let value: String
    var emphasized = false
    var forceLeftToRight = false

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
            Text(key)
                .font(PPOrderMissionTypography.callout())
                .foregroundStyle(Color.ppTextSecondary)
            Spacer(minLength: PPSpace.sm)
            Text(value)
                .font(
                    emphasized
                        ? PPOrderMissionTypography.headline()
                        : PPOrderMissionTypography.callout()
                )
                .foregroundStyle(Color.ppTextPrimary)
                .environment(
                    \.layoutDirection,
                    forceLeftToRight ? .leftToRight : layoutDirection
                )
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PPOrderMissionStatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(PPOrderMissionTypography.caption())
            .foregroundStyle(color)
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, 6)
            .background(color.opacity(0.1), in: Capsule())
    }
}

private struct PPOrderMissionSheetEmptyState: View {
    let symbol: String
    let title: String
    var subtitle: String = ""
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.ppTextTertiary)
                .frame(width: 70, height: 70)
                .background(Color.ppSecondarySurface, in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(PPOrderMissionTypography.title())
                .foregroundStyle(Color.ppTextPrimary)
                .multilineTextAlignment(.center)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(PPOrderMissionTypography.body())
                    .foregroundStyle(Color.ppTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: action) {
                Text(actionTitle)
                    .font(PPOrderMissionTypography.headline())
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(PPGradient.hero)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: PPCorner.medium,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(PPSpace.xl)
        .frame(maxWidth: .infinity, minHeight: 320)
        .accessibilityElement(children: .contain)
    }
}
