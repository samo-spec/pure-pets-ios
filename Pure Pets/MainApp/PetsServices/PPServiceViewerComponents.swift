import SwiftUI
import UIKit

struct PPServiceViewerPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88),
                       value: configuration.isPressed)
    }
}

struct PPServiceViewerTopBar: View {
    let onClose: () -> Void
    let onShare: () -> Void
    let canShare: Bool

    var body: some View {
        HStack(spacing: PPSpace.base) {
            Button(action: onClose) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(PPServiceViewerL10n.text("Back"))

            Text(PPServiceViewerL10n.text("service_view_default_title"))
                .font(PPAccessoryTypography.subheadlineBold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!canShare)
            .accessibilityLabel(PPServiceViewerL10n.text("Share"))
        }
        .foregroundStyle(Color.ppTextPrimary)
        .buttonStyle(PPServiceViewerPressStyle())
        .padding(.horizontal, PPSpace.md)
        .padding(.vertical, PPSpace.xs)
        .background(Color.ppBackground)
    }
}

struct PPServiceViewerIntroduction: View {
    let snapshot: PPServiceViewerSnapshot
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            HStack(alignment: .top, spacing: PPSpace.md) {
                VStack(alignment: .leading, spacing: PPSpace.sm) {
                    if !snapshot.category.isEmpty {
                        Text(snapshot.category)
                            .font(PPAccessoryTypography.subheadlineBold)
                            .foregroundStyle(Color.ppAccentText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(snapshot.title)
                        .font(Font.custom("Beiruti-Bold", size: 36, relativeTo: .largeTitle))
                        .foregroundStyle(Color.ppTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: snapshot.symbol)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.ppAccentText)
                        .frame(width: 56, height: 56)
                        .background(Color.ppSoftRose, in: RoundedRectangle(cornerRadius: PPCorner.medium))
                        .accessibilityHidden(true)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                Image(systemName: snapshot.isLive ? "checkmark.circle" : "pause.circle")
                    .accessibilityHidden(true)
                Text(PPServiceViewerL10n.text(snapshot.isLive ? "Serv_Available" : "service_view_unavailable_banner"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(PPAccessoryTypography.subheadlineBold)
            .foregroundStyle(snapshot.isLive ? Color.ppTextPrimary : Color.ppTextSecondary)
            .accessibilityElement(children: .combine)

            if snapshot.hasImage {
                PPAccessoryRemoteImageView(
                    urlString: snapshot.imageURL,
                    blurHash: snapshot.blurHash,
                    contentMode: .fill,
                    accessibilityLabel: snapshot.title,
                    cacheKey: snapshot.serviceID,
                    displaySize: CGSize(width: 720, height: 420)
                )
                .frame(height: 208)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
            }
        }
        .multilineTextAlignment(.leading)
    }
}

struct PPServiceViewerFacts: View {
    let snapshot: PPServiceViewerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(PPServiceViewerL10n.text("Price"))
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)

                Text(snapshot.price)
                    .font(PPAccessoryTypography.price)
                    .foregroundStyle(Color.ppTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            if !snapshot.serviceTypeText.isEmpty && snapshot.serviceTypeText != snapshot.category {
                fact(PPServiceViewerL10n.text("service_view_type"), value: snapshot.serviceTypeText)
            }
            if let date = snapshot.availableDateText {
                fact(PPServiceViewerL10n.text("service_view_available_date"), value: date)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }

    private func fact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Text(title)
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(Color.ppTextSecondary)
            Text(value)
                .font(PPAccessoryTypography.bodyBold)
                .foregroundStyle(Color.ppTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct PPServiceViewerProvider: View {
    let snapshot: PPServiceViewerSnapshot
    let isLoading: Bool
    let isSignedIn: Bool
    let error: String?
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.base) {
            Text(PPServiceViewerL10n.text("service_note_provided_by"))
                .font(PPAccessoryTypography.captionBold)
                .foregroundStyle(Color.ppTextSecondary)

            HStack(alignment: .top, spacing: PPSpace.md) {
                avatar
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(snapshot.ownerName)
                        .font(PPAccessoryTypography.headline)
                        .foregroundStyle(Color.ppTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if snapshot.ownerVerified {
                        Label(PPServiceViewerL10n.text("service_view_provider_verified"),
                              systemImage: "checkmark.seal.fill")
                            .font(PPAccessoryTypography.caption)
                            .foregroundStyle(Color.ppAccentText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            if isLoading {
                Label {
                    Text(PPServiceViewerL10n.text("service_view_provider_loading"))
                } icon: {
                    ProgressView().tint(Color.ppPrimary)
                }
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(Color.ppTextSecondary)
            } else if let error {
                PPServiceViewerRecovery(message: error, action: onRetry)
            } else if !isSignedIn {
                Text(PPServiceViewerL10n.text("service_note_contact_sign_in"))
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onSignIn) {
                    Text(PPServiceViewerL10n.text("service_note_sign_in"))
                        .font(PPAccessoryTypography.calloutBold)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.ppAccentText)
                .buttonStyle(PPServiceViewerPressStyle())
            } else if !snapshot.hasContact {
                Text(PPServiceViewerL10n.text("service_view_provider_contact_pending"))
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSurface, in: RoundedRectangle(cornerRadius: PPCorner.card))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card)
                .stroke(Color.ppSurfaceBorder, lineWidth: 1)
        }
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder private var avatar: some View {
        if let url = snapshot.ownerAvatarURL, !url.isEmpty {
            PPAccessoryRemoteImageView(
                urlString: url, blurHash: nil, contentMode: .fill,
                accessibilityLabel: snapshot.ownerName, cacheKey: snapshot.ownerID,
                displaySize: CGSize(width: 96, height: 96)
            )
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.ppTextSecondary)
                .frame(width: 48, height: 48)
                .background(Color.ppBackground, in: Circle())
        }
    }
}

struct PPServiceViewerRecovery: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.xs) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(PPServiceViewerL10n.text("Retry"))
                    .font(PPAccessoryTypography.calloutBold)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(Color.ppAccentText)
            .buttonStyle(PPServiceViewerPressStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

struct PPServiceViewerReviewRow: View {
    let item: PPServiceViewerReviewItem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
          HStack(alignment: .top, spacing: PPSpace.md) {
            if let avatar = item.userAvatarURL, !avatar.isEmpty,
               !dynamicTypeSize.isAccessibilitySize {
                PPAccessoryRemoteImageView(
                    urlString: avatar, blurHash: nil, contentMode: .fill,
                    accessibilityLabel: item.userName, isAvatar: true, cacheKey: item.id,
                    displaySize: CGSize(width: 72, height: 72))
                    .frame(width: 36, height: 36).clipShape(Circle())
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(item.userName.isEmpty ? PPServiceViewerL10n.text("service_view_review_anonymous") : item.userName)
                    .font(PPAccessoryTypography.bodyBold)
                    .foregroundStyle(Color.ppTextPrimary)
                Label(PPServiceViewerL10n.format("service_note_rating_format",
                        PPServiceViewerL10n.number(Double(item.rating))), systemImage: "star.fill")
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
            }
            .accessibilityElement(children: .combine)
          }

            if !item.text.isEmpty {
                Text(item.text)
                    .font(PPAccessoryTypography.body)
                    .foregroundStyle(Color.ppTextPrimary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            if let date = item.createdAt {
                Text(PPServiceViewerL10n.date(date))
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
            } else if !item.date.isEmpty {
                Text(item.date)
                    .font(PPAccessoryTypography.caption)
                    .foregroundStyle(Color.ppTextSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .padding(.vertical, PPSpace.base)
    }
}

@available(iOS 15.0, *)
struct PPServiceViewerActionBar: View {
    let snapshot: PPServiceViewerSnapshot
    let isLoadingOwner: Bool
    let isSignedIn: Bool
    let onCall: () -> Void

    private var title: String {
        if !snapshot.isLive { return PPServiceViewerL10n.text("service_view_unavailable_banner") }
        if snapshot.ownerID.isEmpty { return PPServiceViewerL10n.text("service_note_contact_unavailable") }
        if !isSignedIn { return PPServiceViewerL10n.text("service_note_sign_in_contact") }
        if isLoadingOwner { return PPServiceViewerL10n.text("service_note_contact_loading") }
        if !snapshot.hasContact { return PPServiceViewerL10n.text("service_note_contact_unavailable") }
        return PPServiceViewerL10n.text("service_view_contact_provider")
    }

    private var enabled: Bool {
        snapshot.isLive && !snapshot.ownerID.isEmpty && (!isSignedIn || (!isLoadingOwner && snapshot.hasContact))
    }

    var body: some View {
        Button(action: onCall) {
            HStack(spacing: PPSpace.md) {
                if isLoadingOwner && isSignedIn {
                    ProgressView().tint(Color.ppTextSecondary)
                } else {
                    Image(systemName: enabled ? "phone" : "phone.slash")
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(PPAccessoryTypography.bodyBold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PPSpace.lg)
            .padding(.vertical, PPSpace.base)
            .frame(minHeight: PPBottomDecisionBarGeometry.controlHeight)
            .foregroundStyle(enabled ? Color.white : Color.ppTextSecondary)
            .background(enabled ? Color.ppPrimary : Color.ppSecondarySurface,
                        in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .disabled(!enabled)
        .buttonStyle(PPServiceViewerPressStyle())
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.top, PPSpace.md)
        .padding(.bottom, PPSpace.sm)
        .frame(maxWidth: 880)
        .frame(maxWidth: .infinity)
        .background {
            Color.ppSurface
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.ppSurfaceBorder).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

@available(iOS 15.0, *)
struct PPServiceViewerReviewComposer: View {
    @ObservedObject var store: PPServiceViewerStore
    let onClose: () -> Void
    @FocusState private var commentFocused: Bool
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: PPSpace.base) {
                Text(PPServiceViewerL10n.text(store.hasExistingReview
                    ? "service_note_edit_review" : "service_review_composer_title"))
                    .font(PPAccessoryTypography.title)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    commentFocused = false
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(store.isSubmittingReview)
                .accessibilityLabel(PPServiceViewerL10n.text("Close"))
            }
            .padding(.horizontal, PPSpace.lg)
            .padding(.top, PPSpace.md)

            if store.reviewSucceeded {
                success
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: PPSpace.xl) {
                            if let title = store.snapshot?.title {
                                Text(title)
                                    .font(PPAccessoryTypography.bodyBold)
                                    .foregroundStyle(Color.ppTextSecondary)
                            }
                            if let access = store.reviewAccessMessage {
                                Text(access)
                                    .font(PPAccessoryTypography.body)
                                    .foregroundStyle(Color.ppTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !store.isSignedIn {
                                    Button(action: { store.onRequestSignIn?() }) {
                                        Text(PPServiceViewerL10n.text("service_review_sign_in_action"))
                                            .font(PPAccessoryTypography.bodyBold)
                                            .frame(minHeight: 44)
                                    }
                                    .foregroundStyle(Color.ppAccentText)
                                }
                            } else if store.isLoadingOwnReview {
                                ProgressView(PPServiceViewerL10n.text("service_note_review_loading"))
                                    .font(PPAccessoryTypography.body)
                                    .tint(Color.ppPrimary)
                            } else if store.ownReviewChecked {
                                ratingSelection
                                commentInput
                            }

                            if let error = store.reviewError {
                                Label(error, systemImage: "exclamationmark.circle")
                                    .font(PPAccessoryTypography.body)
                                    .foregroundStyle(Color.ppTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityFocused($errorFocused)
                                    .id("review-error")
                                if !store.ownReviewChecked {
                                    Button(action: store.prepareReview) {
                                        Text(PPServiceViewerL10n.text("service_note_reload_review"))
                                            .font(PPAccessoryTypography.calloutBold)
                                            .frame(minHeight: 44)
                                    }
                                    .foregroundStyle(Color.ppAccentText)
                                }
                            }
                        }
                        .frame(maxWidth: 640, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(PPSpace.lg)
                    }
                    .serviceReviewKeyboardDismissal()
                    .serviceViewerOnChange(of: store.reviewError) { error in
                        guard let error else { return }
                        commentFocused = false
                        proxy.scrollTo("review-error", anchor: .center)
                        errorFocused = true
                        UIAccessibility.post(notification: .announcement, argument: error)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { submitAction }
            }
        }
        .foregroundStyle(Color.ppTextPrimary)
        .background(Color.ppBackground.ignoresSafeArea())
        .multilineTextAlignment(.leading)
        .interactiveDismissDisabled(store.isSubmittingReview)
        .onAppear { store.prepareReview() }
        .serviceViewerOnChange(of: store.isSignedIn) { signedIn in
            if signedIn { store.prepareReview() }
        }
        .serviceViewerOnChange(of: store.reviewerAllowed) { allowed in
            if allowed && !store.ownReviewChecked { store.prepareReview() }
        }
        .serviceViewerOnChange(of: store.reviewText) { _ in store.reviewDraftChanged() }
        .serviceViewerOnChange(of: store.reviewRating) { _ in store.reviewDraftChanged() }
        .serviceViewerOnChange(of: store.isSubmittingReview) { submitting in
            if submitting { commentFocused = false }
        }
    }

    private var ratingSelection: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            Text(PPServiceViewerL10n.text("service_note_your_rating"))
                .font(PPAccessoryTypography.headline)

            HStack(spacing: PPSpace.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        guard !store.isSubmittingReview else { return }
                        store.reviewRating = value
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Image(systemName: value <= store.reviewRating ? "star.fill" : "star")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(value <= store.reviewRating
                                ? Color.ppAccentText : Color.ppTextSecondary)
                            .frame(minWidth: 44, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(PPServiceViewerL10n.format("service_note_rate_action",
                        PPServiceViewerL10n.number(Double(value))))
                    .accessibilityAddTraits(store.reviewRating == value ? .isSelected : [])
                }
            }
            .buttonStyle(PPServiceViewerPressStyle())
            .disabled(store.isSubmittingReview)
            .accessibilityElement(children: .contain)

            Text(store.reviewRating == 0
                ? PPServiceViewerL10n.text("service_note_rating_choose")
                : PPServiceViewerL10n.format("service_note_rating_format",
                    PPServiceViewerL10n.number(Double(store.reviewRating))))
                .font(PPAccessoryTypography.callout)
                .foregroundStyle(Color.ppTextSecondary)
        }
    }

    private var commentInput: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(PPServiceViewerL10n.text("service_note_review_comment"))
                    .font(PPAccessoryTypography.headline)
                Spacer(minLength: PPSpace.sm)
                if commentFocused {
                    Button(PPServiceViewerL10n.text("Done")) { commentFocused = false }
                        .font(PPAccessoryTypography.calloutBold)
                        .foregroundStyle(Color.ppAccentText)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            TextEditor(text: $store.reviewText)
                .font(PPAccessoryTypography.body)
                .frame(minHeight: 140)
                .padding(PPSpace.sm)
                .background(Color.ppSurface,
                            in: RoundedRectangle(cornerRadius: PPCorner.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: PPCorner.medium)
                        .stroke(commentFocused ? Color.ppAccentText : Color.ppTextSecondary, lineWidth: 1)
                }
                .tint(Color.ppAccentText)
                .focused($commentFocused)
                .disabled(store.isSubmittingReview)
                .accessibilityLabel(PPServiceViewerL10n.text("service_note_review_comment"))
            Text(PPServiceViewerL10n.format("service_note_review_remaining",
                PPServiceViewerL10n.number(Double(max(0, 600 - store.reviewText.utf16.count)))))
                .font(PPAccessoryTypography.caption)
                .foregroundStyle(Color.ppTextSecondary)
                .accessibilityHidden(true)
            if store.reviewText.utf16.count > 600 {
                Text(PPServiceViewerL10n.text("service_note_review_too_long"))
                    .font(PPAccessoryTypography.callout)
                    .foregroundStyle(Color.ppTextPrimary)
            }
        }
    }

    private var submitAction: some View {
        Button {
            commentFocused = false
            store.submitReview()
        } label: {
            HStack(spacing: PPSpace.sm) {
                if store.isSubmittingReview { ProgressView().tint(.white) }
                Text(PPServiceViewerL10n.text(store.isSubmittingReview
                    ? "service_note_review_saving"
                    : store.hasExistingReview ? "service_note_update_review" : "service_review_submit"))
                    .font(PPAccessoryTypography.bodyBold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(PPSpace.base)
            .frame(minHeight: 54)
            .foregroundStyle(Color.white)
            .background(Color.ppPrimary, in: RoundedRectangle(cornerRadius: PPCorner.medium))
            .opacity(store.reviewAccessMessage == nil && store.reviewRating > 0 ? 1 : 0.45)
        }
        .disabled(store.isSubmittingReview || store.isLoadingOwnReview
            || !store.ownReviewChecked || store.reviewAccessMessage != nil || store.reviewRating == 0)
        .buttonStyle(PPServiceViewerPressStyle())
        .padding(PPSpace.base)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .background(Color.ppSurface.ignoresSafeArea(edges: .bottom))
    }

    private var success: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.ppAccentText)
                .accessibilityHidden(true)
            Text(PPServiceViewerL10n.text("service_note_review_saved"))
                .font(PPAccessoryTypography.hero)
                .accessibilityAddTraits(.isHeader)
            Text(PPServiceViewerL10n.text("service_review_success_subtitle"))
                .font(PPAccessoryTypography.body)
                .foregroundStyle(Color.ppTextSecondary)
            Button(action: onClose) {
                Text(PPServiceViewerL10n.text("Done"))
                    .font(PPAccessoryTypography.bodyBold)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(Color.white)
                    .background(Color.ppPrimary,
                                in: RoundedRectangle(cornerRadius: PPCorner.medium))
            }
            .buttonStyle(PPServiceViewerPressStyle())
        }
        .frame(maxWidth: 640, alignment: .leading)
        .padding(PPSpace.xl)
        .frame(maxWidth: .infinity)
      }
    }
}

private extension View {
    @ViewBuilder func serviceReviewKeyboardDismissal() -> some View {
        if #available(iOS 16.0, *) { self.scrollDismissesKeyboard(.interactively) }
        else { self }
    }
}

// Keep the current callback form on modern iOS and the supported iOS 15/16
// callback on those systems, without duplicating any model or lifecycle state.
@available(iOS 15.0, *)
private struct PPServiceViewerChange<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (Value) -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            content.onChange(of: value, perform: action)
        }
    }
}

extension View {
    @available(iOS 15.0, *)
    func serviceViewerOnChange<Value: Equatable>(
        of value: Value, perform action: @escaping (Value) -> Void
    ) -> some View {
        modifier(PPServiceViewerChange(value: value, action: action))
    }
}
