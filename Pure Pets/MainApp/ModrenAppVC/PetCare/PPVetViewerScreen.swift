//
//  PPVetViewerScreen.swift
//  Pure Pets
//
//  Care introductions: a person-led vet profile and a place-led clinic profile.
//  Presentation only. Navigation and external contact remain UIKit-owned.
//

import SwiftUI

struct PPVetViewerSnapshot: Equatable {
    let id: String
    let title: String
    let isCompany: Bool
    let logoURL: String?
    let bio: String
    let consultationAmountText: String?
    let consultationCostText: String
    let hasPublishedFee: Bool
    let isReadyToContact: Bool
    let phone: String
    let whatsapp: String
    let canCall: Bool
    let canWhatsApp: Bool
    let isListed: Bool
    let isVerified: Bool
    let membershipText: String?
    let availableDateText: String
    let speciesNames: [String]
    let speciesSummary: String
    let languageCode: String
    let isRTL: Bool

    let cityName: String?
    let workingAreas: [String]
    let address: String?
    let licenseNumber: String?
    let workingHours: String?
    let emergency247: Bool
    let homeVisitAvailable: Bool

    init(content: PPVetViewerContent) {
        isRTL = Language.isRTL()
        languageCode = Language.currentLanguageCode()
        let locale = Locale(identifier: isRTL ? "ar_QA" : "en_QA")
        func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
        isCompany = content.isCompany
        title = clean(content.title).isEmpty
            ? PPVetDetailLocalization.text(content.isCompany ? "vet_detail_clinic" : "vet_detail_doctor")
            : clean(content.title)
        id = content.vetID.isEmpty ? "\(content.isCompany ? "clinic" : "vet"):\(title)" : content.vetID
        let candidate = URL(string: clean(content.logoURL))
        logoURL = candidate.flatMap { url in
            guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.isEmpty == false else { return nil }
            return url.absoluteString
        }
        bio = clean(content.descriptionText)
        isListed = PPVetContactRouting.isContactAllowed(status: content.verificationStatus, disabled: content.isDisabled)
        isReadyToContact = content.readyToContact
        phone = PPVetContactRouting.normalizedPhone(content.phone) ?? ""
        whatsapp = PPVetContactRouting.normalizedPhone(content.whatsapp) ?? ""
        canCall = isListed && PPVetContactRouting.callURL(phone: content.phone, whatsapp: content.whatsapp) != nil
        canWhatsApp = isListed && PPVetContactRouting.whatsAppURL(phone: content.phone, whatsapp: content.whatsapp) != nil
        // Approval and a paid membership are not professional accreditation.
        isVerified = clean(content.verificationStatus).lowercased() == "verified"
        hasPublishedFee = content.vetCost.isFinite && content.vetCost > 0
        let amount = NumberFormatter()
        amount.locale = locale
        amount.numberStyle = .decimal
        amount.maximumFractionDigits = 2
        consultationAmountText = hasPublishedFee ? amount.string(from: NSNumber(value: content.vetCost)) : nil
        let currency = NumberFormatter()
        currency.locale = locale
        currency.numberStyle = .currency
        currency.currencyCode = "QAR"
        currency.minimumFractionDigits = 0
        currency.maximumFractionDigits = 2
        consultationCostText = hasPublishedFee
            ? currency.string(from: NSNumber(value: content.vetCost)) ?? PPVetDetailLocalization.text("vet_detail_confirm_fee")
            : PPVetDetailLocalization.text("vet_detail_confirm_fee")
        if content.subscriptionActive {
            let number = NumberFormatter()
            number.locale = locale
            number.numberStyle = .decimal
            let tier = number.string(from: NSNumber(value: content.subscriptionTier)) ?? ""
            membershipText = content.subscriptionTier > 0 && !tier.isEmpty
                ? String(format: PPVetDetailLocalization.text("vet_detail_membership_tier"), tier)
                : PPVetDetailLocalization.text("vet_detail_membership_active")
        } else {
            membershipText = nil
        }
        if let date = content.availableDate {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            availableDateText = formatter.string(from: date)
        } else {
            availableDateText = clean(content.availableDateText)
        }
        var names: [String] = []
        for rawName in content.animalTypes + [content.mainKindName] {
            let name = clean(rawName)
            // Taxonomy IDs are resolved at the controller boundary, never shown as species names.
            guard !name.isEmpty, !name.allSatisfy({ $0.isNumber }),
                  !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
            names.append(name)
        }
        speciesNames = names
        let list = ListFormatter()
        list.locale = locale
        speciesSummary = list.string(from: names) ?? names.joined(separator: " · ")

        // Clinical Practice, Location, Emergency & Accreditation
        let cCity = clean(content.cityName)
        cityName = cCity.isEmpty ? nil : cCity
        workingAreas = content.workingAreas
        let cAddress = clean(content.address)
        address = cAddress.isEmpty ? nil : cAddress
        let cLicense = clean(content.licenseNumber)
        licenseNumber = cLicense.isEmpty ? nil : cLicense
        let cHours = clean(content.workingHours)
        workingHours = cHours.isEmpty ? nil : cHours
        emergency247 = content.emergency247
        homeVisitAvailable = content.homeVisitAvailable
    }
}


struct PPVetViewerScreen: View {
    @ObservedObject var presentation: PPVetViewerPresentation
    let onCall: () -> Void
    let onWhatsApp: () -> Void
    let onShare: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFullBiography = false

    private var snapshot: PPVetViewerSnapshot { presentation.snapshot }
    private var largeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 760 && !largeText
            let inlineContact = largeText || geometry.size.height < 500
            let width = max(1, min(980, geometry.size.width - PPSpace.screenMargin * 2))
            ScrollView {
                VStack(alignment: .leading, spacing: PPSpace.xl) {
                    if snapshot.isListed {
                        if wide {
                            HStack(alignment: .top, spacing: PPSpace.xxl) {
                                profileFolio(width: width * 0.46)
                                    .frame(width: width * 0.46)
                                profileDetails
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            profileFolio(width: width)
                            profileDetails
                        }
                        if inlineContact { contactActions(stacked: true) }
                    } else {
                        unavailableProfile
                    }
                }
                .frame(width: width, alignment: .leading)
                .padding(.top, PPSpace.md)
                .padding(.bottom, PPSpace.xl)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .top, spacing: 0) { navigationBar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if snapshot.isListed && !inlineContact {
                    contactActions(stacked: false)
                        .frame(maxWidth: 640)
                        .padding(.horizontal, PPSpace.screenMargin)
                        .padding(.top, PPSpace.md)
                        .padding(.bottom, PPSpace.sm)
                        .frame(maxWidth: .infinity)
                        .background(Color.ppSurface)
                        .overlay(alignment: .top) { Divider().overlay(Color.ppSurfaceBorder) }
                }
            }
        }
        .background(Color.ppBackground.ignoresSafeArea())
        .foregroundColor(.ppTextPrimary)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: snapshot.isRTL ? "ar_QA" : "en_QA"))
    }

    private var navigationBar: some View {
        HStack(spacing: PPSpace.md) {
            navigationButton(symbol: snapshot.isRTL ? "chevron.right" : "chevron.left",
                             label: copy("vet_detail_back"), identifier: "vetDetail.back", action: onDismiss)
            VStack(spacing: 0) {
                Text(copy("vet_detail_profile"))
                    .font(font(19, bold: true, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            navigationButton(symbol: "square.and.arrow.up", label: copy("vet_detail_share"),
                             identifier: "vetDetail.share", action: onShare)
                .disabled(!snapshot.isListed)
                .opacity(snapshot.isListed ? 1 : 0.4)
        }
        .padding(.horizontal, PPSpace.screenMargin)
        .padding(.vertical, PPSpace.xs)
        .frame(maxWidth: 1020)
        .frame(maxWidth: .infinity)
        .background(Color.ppBackground)
    }

    private func navigationButton(symbol: String, label: String, identifier: String,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Color.ppSurface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PPVetDetailPressStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    // The image, identity, care scope and fee are one reading surface, not four competing cards.
    private func profileFolio(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = snapshot.logoURL {
                portrait(url: url, size: CGSize(width: width, height: min(260, width * 0.64)))
            }
            VStack(alignment: .leading, spacing: PPSpace.md) {
                HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                    Image(systemName: snapshot.isCompany ? "cross.case" : "stethoscope")
                        .font(.system(size: 15, weight: .medium))
                        .accessibilityHidden(true)
                    Text(copy(snapshot.isCompany ? "vet_detail_clinic" : "vet_detail_doctor"))
                        .font(font(17, bold: true, relativeTo: .subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if snapshot.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .accessibilityLabel(copy("vet_detail_profile_verified"))
                    }
                }
                .foregroundColor(.ppPrimary)
                Text(verbatim: snapshot.title)
                    .font(font(34, bold: true, relativeTo: .largeTitle))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("vetDetail.name")
                if !snapshot.speciesSummary.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: PPSpace.sm) {
                        Image(systemName: "pawprint")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.ppPrimary)
                            .accessibilityHidden(true)
                        Text(verbatim: snapshot.speciesSummary)
                            .font(font(19, relativeTo: .body))
                            .foregroundColor(.ppTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy("vet_detail_scope") + ": " + snapshot.speciesSummary)
                }
            }
            .padding(PPSpace.lg)
            consultationSeam(stacked: largeText || width < 330)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ppSurface)
        .clipShape(RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PPCorner.hero, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func portrait(url: String, size: CGSize) -> some View {
        AppRemoteImage(urlString: url, displaySize: size,
                       contentMode: snapshot.isCompany ? .fit : .fill) {
            imagePlaceholder(size: size, loading: true)
        } failurePlaceholder: {
            imagePlaceholder(size: size, loading: false)
        }
        .frame(width: size.width, height: size.height)
        .background(snapshot.isCompany ? Color.ppSurface : Color.ppQuietLilac)
        .clipped()
        .accessibilityLabel(String(format: copy("vet_detail_image_label"), snapshot.title))
        .accessibilityElement(children: .contain)
    }

    private func imagePlaceholder(size: CGSize, loading: Bool) -> some View {
        VStack(spacing: PPSpace.md) {
            Image(systemName: snapshot.isCompany ? "cross.case" : "person.crop.rectangle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.ppPrimary)
                .accessibilityHidden(true)
            if loading {
                ProgressView().tint(.ppPrimary)
                    .accessibilityLabel(copy("vet_detail_image_loading"))
            } else {
                Text(copy("vet_detail_image_missing"))
                    .font(font(17, relativeTo: .subheadline))
                    .foregroundColor(.ppTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.ppQuietLilac)
    }

    private func consultationSeam(stacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(Color.ppSurfaceBorder)
            Group {
                if stacked {
                    VStack(alignment: .leading, spacing: PPSpace.sm) {
                        feeLabel
                        feeValue
                    }
                } else {
                    HStack(alignment: .center, spacing: PPSpace.lg) {
                        feeLabel.frame(maxWidth: .infinity, alignment: .leading)
                        feeValue.layoutPriority(1)
                    }
                }
            }
            .padding(.horizontal, PPSpace.lg)
            .padding(.vertical, PPSpace.base)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ppSoftRose.opacity(0.45))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy("vet_detail_consultation_fee"))
        .accessibilityValue(snapshot.consultationCostText)
    }

    private var feeLabel: some View {
        Text(copy("vet_detail_consultation_fee"))
            .font(font(18, relativeTo: .body))
            .foregroundColor(.ppTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var feeValue: some View {
        if let amount = snapshot.consultationAmountText {
            // Keep digits and currency in separate semantic runs so Arabic bidi cannot reorder the amount.
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: amount)
                    .font(font(32, bold: true, relativeTo: .title))
                    .environment(\.layoutDirection, .leftToRight)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy("vet_detail_currency"))
                    .font(font(15, relativeTo: .caption))
                    .foregroundColor(.ppTextSecondary)
            }
        } else {
            Text(copy("vet_detail_confirm_fee"))
                .font(font(19, bold: true, relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var profileDetails: some View {
        VStack(alignment: .leading, spacing: PPSpace.xl) {
            clinicalHighlights
            locationAndFacility
            biography
            preparation
            contactDetails
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var clinicalHighlights: some View {
        if snapshot.emergency247 || snapshot.homeVisitAvailable {
            VStack(alignment: .leading, spacing: PPSpace.sm) {
                if snapshot.emergency247 {
                    HStack(alignment: .top, spacing: PPSpace.sm) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.92, green: 0.35, blue: 0.28).opacity(0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 0.92, green: 0.35, blue: 0.28))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy("vet_detail_emergency_badge"))
                                .font(font(17, bold: true, relativeTo: .headline))
                                .foregroundColor(Color(red: 0.92, green: 0.35, blue: 0.28))
                            Text(copy("vet_detail_emergency_desc"))
                                .font(font(14, relativeTo: .subheadline))
                                .foregroundColor(.ppTextSecondary)
                        }
                    }
                    .padding(PPSpace.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.92, green: 0.35, blue: 0.28).opacity(0.06), in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                            .strokeBorder(Color(red: 0.92, green: 0.35, blue: 0.28).opacity(0.20), lineWidth: 0.8)
                    )
                }

                if snapshot.homeVisitAvailable {
                    HStack(alignment: .top, spacing: PPSpace.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: "car.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy("vet_detail_home_visit_badge"))
                                .font(font(17, bold: true, relativeTo: .headline))
                                .foregroundColor(Color.blue)
                            Text(copy("vet_detail_home_visit_desc"))
                                .font(font(14, relativeTo: .subheadline))
                                .foregroundColor(.ppTextSecondary)
                        }
                    }
                    .padding(PPSpace.base)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.20), lineWidth: 0.8)
                    )
                }
            }
        }
    }

    @ViewBuilder private var locationAndFacility: some View {
        if snapshot.cityName != nil || snapshot.address != nil || !snapshot.workingAreas.isEmpty {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                sectionTitle(copy("vet_detail_location_title"))
                if let city = snapshot.cityName, !city.isEmpty {
                    informationRow(label: copy("vet_detail_city"), value: city, symbol: "building.columns")
                }
                if let addr = snapshot.address, !addr.isEmpty {
                    informationRow(label: copy("vet_detail_address"), value: addr, symbol: "signpost.right")
                }
                if !snapshot.workingAreas.isEmpty {
                    let areaNames: [String] = snapshot.workingAreas.compactMap { key in
                        let localized = Language.get(key, alter: key)
                        if let loc = localized, !loc.isEmpty {
                            return loc
                        }
                        return key
                    }
                    let summary = areaNames.joined(separator: " · ")
                    informationRow(label: copy("vet_detail_coverage_areas"), value: summary, symbol: "map")
                }
            }
        }
    }

    private var biography: some View {
        VStack(alignment: .leading, spacing: PPSpace.sm) {
            sectionTitle(copy(snapshot.isCompany ? "vet_detail_about_clinic" : "vet_detail_about_doctor"))
            Text(verbatim: snapshot.bio.isEmpty ? copy("vet_detail_bio_missing") : snapshot.bio)
                .font(font(21, relativeTo: .body))
                .foregroundColor(snapshot.bio.isEmpty ? .ppTextSecondary : .ppTextPrimary)
                .lineSpacing(3)
                .lineLimit(snapshot.bio.count > 550 && !showsFullBiography && !largeText ? 6 : nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            if snapshot.bio.count > 550 && !largeText {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { showsFullBiography.toggle() }
                } label: {
                    Label(copy(showsFullBiography ? "vet_detail_read_less" : "vet_detail_read_more"),
                          systemImage: showsFullBiography ? "minus" : "plus")
                        .font(font(18, bold: true, relativeTo: .body))
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .foregroundColor(.ppPrimary)
                .buttonStyle(PPVetDetailPressStyle())
                .accessibilityIdentifier("vetDetail.biographyDisclosure")
            }
        }
    }

    private var preparation: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            sectionTitle(copy("vet_detail_prepare_title"))
            if snapshot.speciesNames.isEmpty {
                informationRow(label: copy("vet_detail_animals"), value: copy("vet_detail_animals_missing"), symbol: "pawprint")
            }
            if let license = snapshot.licenseNumber, !license.isEmpty {
                informationRow(label: copy("vet_detail_license"), value: license, symbol: "checkmark.seal")
            }
            if let hours = snapshot.workingHours, !hours.isEmpty {
                informationRow(label: copy("vet_detail_working_hours"), value: hours, symbol: "clock")
            }
            if !snapshot.availableDateText.isEmpty {
                informationRow(label: copy("vet_detail_listed_availability"), value: snapshot.availableDateText, symbol: "calendar")
            }
            if let membership = snapshot.membershipText {
                informationRow(label: copy("vet_detail_membership"), value: membership, symbol: "pawprint.circle")
            }
            Text(copy(snapshot.isReadyToContact && (snapshot.canCall || snapshot.canWhatsApp)
                      ? "vet_detail_contact_enabled" : "vet_detail_confirm_visit"))
                .font(font(17, relativeTo: .subheadline))
                .foregroundColor(.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }


    @ViewBuilder private var contactDetails: some View {
        if !snapshot.phone.isEmpty || !snapshot.whatsapp.isEmpty {
            VStack(alignment: .leading, spacing: PPSpace.md) {
                sectionTitle(copy("vet_detail_contact_title"))
                if !snapshot.phone.isEmpty {
                    informationRow(label: copy("vet_detail_phone"), value: snapshot.phone, symbol: "phone", telephone: true)
                }
                if !snapshot.whatsapp.isEmpty && snapshot.whatsapp != snapshot.phone {
                    informationRow(label: copy("vet_detail_whatsapp"), value: snapshot.whatsapp, symbol: "message", telephone: true)
                }
                if snapshot.canCall && !snapshot.canWhatsApp {
                    Text(copy("vet_detail_whatsapp_international"))
                        .font(font(17, relativeTo: .subheadline))
                        .foregroundColor(.ppTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func informationRow(label: String, value: String, symbol: String, telephone: Bool = false) -> some View {
        VStack(spacing: PPSpace.md) {
            Divider().overlay(Color.ppSurfaceBorder)
            HStack(alignment: .top, spacing: PPSpace.md) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.ppPrimary)
                    .frame(width: 24, height: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: PPSpace.xs) {
                    Text(label)
                        .font(font(16, relativeTo: .subheadline))
                        .foregroundColor(.ppTextSecondary)
                    Text(verbatim: value)
                        .font(font(21, relativeTo: .body))
                        .environment(\.layoutDirection, telephone ? .leftToRight : (snapshot.isRTL ? .rightToLeft : .leftToRight))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func contactActions(stacked: Bool) -> some View {
        if snapshot.canCall || snapshot.canWhatsApp {
            if stacked {
                VStack(alignment: .leading, spacing: PPSpace.md) {
                    sectionTitle(copy("vet_detail_get_in_touch"))
                    contactButton(whatsApp: false)
                    contactButton(whatsApp: true)
                }
            } else {
                HStack(spacing: PPSpace.md) {
                    contactButton(whatsApp: false)
                    contactButton(whatsApp: true)
                }
            }
        } else {
            Label(copy("vet_detail_contact_missing"), systemImage: "phone")
                .font(font(18, relativeTo: .body))
                .foregroundColor(.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, PPSpace.sm)
                .accessibilityIdentifier("vetDetail.contactUnavailable")
        }
    }

    private func contactButton(whatsApp: Bool) -> some View {
        let enabled = whatsApp ? snapshot.canWhatsApp : snapshot.canCall
        let primary = !whatsApp || !snapshot.canCall
        return Button(action: whatsApp ? onWhatsApp : onCall) {
            HStack(spacing: PPSpace.sm) {
                Image(systemName: whatsApp ? "message" : "phone.fill")
                    .font(.system(size: 19, weight: .medium))
                    .accessibilityHidden(true)
                Text(copy(whatsApp ? "vet_detail_whatsapp" : "vet_detail_call"))
                    .font(font(20, bold: true, relativeTo: .headline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: PPBottomDecisionBarGeometry.controlHeight)
            .padding(.horizontal, PPSpace.md)
            .padding(.vertical, PPSpace.xs)
            .foregroundColor(enabled ? (primary ? .white : .ppTextPrimary) : .ppTextSecondary)
            .background(enabled && primary ? Color.ppPrimary : Color.ppSecondarySurface,
                        in: RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous))
        }
        .buttonStyle(PPVetDetailPressStyle())
        .disabled(!enabled)
        .accessibilityHint(copy(enabled ? (whatsApp ? "vet_detail_whatsapp_hint" : "vet_detail_call_hint")
                               : "vet_detail_channel_missing"))
        .accessibilityIdentifier(whatsApp ? "vetDetail.whatsapp" : "vetDetail.call")
    }

    private var unavailableProfile: some View {
        VStack(alignment: .leading, spacing: PPSpace.lg) {
            Image(systemName: "cross.case").font(.system(size: 40, weight: .light))
                .foregroundColor(.ppPrimary).accessibilityHidden(true)
            sectionTitle(copy("vet_detail_unavailable_title"))
            Text(copy("vet_detail_unavailable_body"))
                .font(font(21, relativeTo: .body))
                .foregroundColor(.ppTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, PPSpace.xxl)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(font(23, bold: true, relativeTo: .title2))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func font(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle) -> Font {
        .custom(bold ? "Beiruti-Bold" : "Beiruti-Regular", size: size, relativeTo: style)
    }

    private func copy(_ key: String) -> String { PPVetDetailLocalization.text(key) }
}

private struct PPVetDetailPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
