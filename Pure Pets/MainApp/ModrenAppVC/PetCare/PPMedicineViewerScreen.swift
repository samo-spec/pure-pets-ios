import SwiftUI

/// A package-first medicine record. This view never infers dosage, suitability,
/// prescription class, certification, storage conditions, or clinical benefits.
struct PPMedicineViewerScreen: View {
    @ObservedObject var presentation: PPMedicineViewerPresentation
    let onReturnToCare: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var accessibleImageHeight: CGFloat = 120

    private var snapshot: PPMedicineViewerSnapshot { presentation.snapshot }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 700 && !dynamicTypeSize.isAccessibilitySize
            let margin = geometry.size.width < 380 ? PPSpace.base : PPSpace.xl

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: PPSpace.xxl) {
                    if wide {
                        HStack(alignment: .top, spacing: PPSpace.xxxl) {
                            packageImage(width: min(360, geometry.size.width * 0.4))
                                .frame(width: min(360, geometry.size.width * 0.4))
                            VStack(alignment: .leading, spacing: PPSpace.xl) {
                                identity
                                priceAndAvailability
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        identity
                        if dynamicTypeSize.isAccessibilitySize {
                            priceAndAvailability
                        }
                        packageImage(width: max(1, geometry.size.width - margin * 2))
                        if !dynamicTypeSize.isAccessibilitySize {
                            priceAndAvailability
                        }
                    }

                    recordRule
                    descriptionSection
                    factsSection(stacked: dynamicTypeSize.isAccessibilitySize || geometry.size.width < 380)
                    guidanceSection
                }
                .frame(maxWidth: 960, alignment: .leading)
                .padding(.horizontal, margin)
                .padding(.top, PPSpace.xl)
                .padding(.bottom, PPSpace.xxl)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color.ppBackground)
        }
        .foregroundStyle(Color.ppTextPrimary)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: snapshot.languageCode))
        .accessibilityIdentifier("medicine_record.screen")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: "pills")
                    .foregroundStyle(Color.ppCareAccent)
                    .accessibilityHidden(true)
                Text(PPMedicineViewerL10n.text("medicine_record_eyebrow"))
                    .font(medicineFont(14, style: .subheadline, bold: true))
                    .foregroundStyle(Color.ppTextSecondary)
                Rectangle()
                    .fill(separatorColor)
                    .frame(maxWidth: PPSpace.xxxxl, minHeight: 1, maxHeight: 1)
                    .accessibilityHidden(true)
            }

            Text(verbatim: snapshot.title)
                .font(medicineFont(32, style: .largeTitle, bold: true))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("medicine_record.title")

            if !snapshot.category.isEmpty {
                Text(verbatim: snapshot.category)
                    .font(medicineFont(17, style: .body))
                    .foregroundStyle(Color.ppTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func packageImage(width: CGFloat) -> some View {
        let height: CGFloat = dynamicTypeSize.isAccessibilitySize
            ? max(176, accessibleImageHeight) : (width < 350 ? 212 : 256)
        return VStack(spacing: 0) {
            Group {
                if snapshot.imageURL.isEmpty {
                    imageFallback(retry: false)
                } else {
                    AppRemoteImage(
                        urlString: snapshot.imageURL,
                        displaySize: CGSize(width: max(1, width - PPSpace.xxl * 2), height: height),
                        contentMode: .fit,
                        fadeDuration: 0.18,
                        showsRetryAction: true
                    ) {
                        VStack(spacing: PPSpace.md) {
                            ProgressView()
                                .tint(Color.ppCareAccent)
                            Text(PPMedicineViewerL10n.text("medicine_record_image_loading"))
                                .font(medicineFont(14, style: .footnote))
                                .foregroundStyle(Color.ppTextSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } failurePlaceholder: {
                        imageFallback(retry: true)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(PPSpace.xl)

            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                Image(systemName: "photo")
                    .accessibilityHidden(true)
                Text(PPMedicineViewerL10n.text("medicine_record_product_photo"))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(PPMedicineViewerL10n.format("medicine_record_image_format", snapshot.title))
            }
            .font(medicineFont(13, style: .caption))
            .foregroundStyle(Color.ppTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PPSpace.lg)
            .padding(.vertical, PPSpace.md)
            .background(Color.ppSecondarySurface)
        }
        .background(Color.ppSurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(separatorColor, lineWidth: contrast == .increased ? 1.5 : 1)
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("medicine_record.package")
    }

    private func imageFallback(retry: Bool) -> some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: retry ? "arrow.clockwise" : "pills")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.ppCareAccent)
                .accessibilityHidden(true)
            Text(PPMedicineViewerL10n.text(retry ? "medicine_record_image_retry" : "medicine_record_image_missing"))
                .font(medicineFont(16, style: .callout))
                .foregroundStyle(Color.ppTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var priceAndAvailability: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            VStack(alignment: .leading, spacing: PPSpace.xs) {
                Text(PPMedicineViewerL10n.text("medicine_record_unit_price"))
                    .font(medicineFont(14, style: .subheadline))
                    .foregroundStyle(Color.ppTextSecondary)
                Text(verbatim: PPMedicineViewerL10n.isolated(snapshot.displayPrice))
                    .font(medicineFont(28, style: .title, bold: true))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("medicine_record.price")
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: availabilitySymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(snapshot.availability == .available ? Color.ppCareAccent : Color.ppTextSecondary)
                    .padding(.top, PPSpace.xs)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(availabilityTitle)
                        .font(medicineFont(18, style: .headline, bold: true))
                    if let detail = availabilityDetail {
                        Text(verbatim: detail)
                            .font(medicineFont(16, style: .callout))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                    if !snapshot.cartText.isEmpty {
                        Text(verbatim: snapshot.cartText)
                            .font(medicineFont(15, style: .footnote, bold: true))
                            .foregroundStyle(Color.ppTextSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("medicine_record.availability")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionTitle("medicine_record_description")
            Text(verbatim: snapshot.descriptionText.isEmpty
                 ? PPMedicineViewerL10n.text("medicine_record_description_missing")
                 : snapshot.descriptionText)
                .font(medicineFont(18, style: .body))
                .foregroundStyle(snapshot.descriptionText.isEmpty ? Color.ppTextSecondary : Color.ppTextPrimary)
                .lineSpacing(PPSpace.xs)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("medicine_record.description")
        }
    }

    private func factsSection(stacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            sectionTitle("medicine_record_details")
            VStack(spacing: 0) {
                factRow("pet_care_viewer_category", value: snapshot.category, stacked: stacked)
                recordRule
                factRow("medicine_record_listed_species", value: snapshot.species, stacked: stacked)
                if !snapshot.discoveryContext.isEmpty {
                    recordRule
                    factRow("medicine_record_browsing_for", value: snapshot.discoveryContext, stacked: stacked)
                }
                if !snapshot.addedDateText.isEmpty {
                    recordRule
                    factRow("pet_care_viewer_added_date", value: snapshot.addedDateText, stacked: stacked)
                }
            }
        }
    }

    private func factRow(_ key: String, value: String, stacked: Bool) -> some View {
        let label = Text(PPMedicineViewerL10n.text(key))
            .font(medicineFont(16, style: .callout))
            .foregroundStyle(Color.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        let content = Text(verbatim: value.isEmpty ? PPMedicineViewerL10n.text("medicine_record_not_supplied") : value)
            .font(medicineFont(17, style: .body, bold: true))
            .fixedSize(horizontal: false, vertical: true)

        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    label
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.lg) {
                    label.frame(maxWidth: .infinity, alignment: .leading)
                    content
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, PPSpace.md)
        .accessibilityElement(children: .combine)
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                Image(systemName: "cross.case")
                    .foregroundStyle(Color.ppCareAccent)
                    .accessibilityHidden(true)
                sectionTitle("medicine_record_before_use")
            }
            Text(PPMedicineViewerL10n.text("medicine_record_guidance"))
                .font(medicineFont(17, style: .body))
                .foregroundStyle(Color.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if snapshot.canReturnToCare {
                Button(action: onReturnToCare) {
                    HStack(spacing: PPSpace.md) {
                        Text(PPMedicineViewerL10n.text("medicine_record_back_to_care"))
                            .font(medicineFont(17, style: .headline, bold: true))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: PPSpace.sm)
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, PPSpace.base)
                    .padding(.vertical, PPSpace.xs)
                    .contentShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
                }
                .buttonStyle(PPMedicineRecordButtonStyle())
                .accessibilityIdentifier("medicine_record.back_to_care")
            }
        }
        .padding(PPSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSecondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous))
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(PPMedicineViewerL10n.text(key))
            .font(medicineFont(21, style: .title3, bold: true))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var recordRule: some View {
        Rectangle().fill(separatorColor).frame(height: 1).accessibilityHidden(true)
    }

    private var separatorColor: Color {
        contrast == .increased ? Color.ppTextSecondary : Color.ppSeparator
    }

    private var availabilitySymbol: String {
        switch snapshot.availability {
        case .available: return "checkmark.circle.fill"
        case .allInCart: return "cart.fill"
        case .soldOut, .unavailable: return "minus.circle"
        }
    }

    private var availabilityTitle: String {
        switch snapshot.availability {
        case .available: return PPMedicineViewerL10n.text("pet_care_medicine_available")
        case .allInCart: return PPMedicineViewerL10n.text("medicine_record_all_in_cart")
        case .soldOut: return PPMedicineViewerL10n.text("pet_care_medicine_out_of_stock")
        case .unavailable: return PPMedicineViewerL10n.text("pet_care_medicine_not_available")
        }
    }

    private var availabilityDetail: String? {
        switch snapshot.availability {
        case .available: return snapshot.stockText
        case .allInCart: return PPMedicineViewerL10n.text("pet_care_viewer_cart_limit_copy")
        case .soldOut, .unavailable: return PPMedicineViewerL10n.text("medicine_record_unavailable_detail")
        }
    }
}

private func medicineFont(_ size: CGFloat, style: Font.TextStyle, bold: Bool = false) -> Font {
    .custom(bold ? "Beiruti-Bold" : "Beiruti-Regular", size: size, relativeTo: style)
}

private struct PPMedicineRecordButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.ppTextPrimary)
            .background(configuration.isPressed ? Color.ppSurfaceBorder : Color.ppSurface)
            .clipShape(RoundedRectangle(cornerRadius: PPCorner.small, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion && scenePhase == .active ? 0.985 : 1)
            .animation(reduceMotion || scenePhase != .active ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
