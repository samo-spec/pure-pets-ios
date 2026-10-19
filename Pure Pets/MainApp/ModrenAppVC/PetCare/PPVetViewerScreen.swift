//
//  PPVetViewerScreen.swift
//  Pure Pets
//
//  Reinvented from absolute first principles for NextGen V6 Flagship.
//  Category-defining clinical sanctuary details screen in SwiftUI.
//

import SwiftUI

// MARK: - Viewer Snapshot
struct PPVetViewerSnapshot: Equatable {
    let id: String
    let title: String
    let isCompany: Bool
    let typeTitle: String
    let logoURL: String
    let bio: String
    let consultationCostText: String
    let isFreeConsult: Bool
    let isReadyToContact: Bool
    let statusTitle: String
    let readinessDetail: String
    let phone: String
    let whatsapp: String
    let canCall: Bool
    let canWhatsApp: Bool
    let isVerified: Bool
    let membershipText: String
    let availableDateText: String
    let speciesList: [PPVetSpeciesItem]
    let languageCode: String
    let isRTL: Bool

    init(content: PPVetViewerContent) {
        let isRTL = Language.isRTL()
        self.isRTL = isRTL
        self.languageCode = Language.currentLanguageCode()

        self.id = content.vetID.isEmpty ? UUID().uuidString : content.vetID
        let rawTitle = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = rawTitle.isEmpty
            ? (Language.get("pet_care_vet_untitled", alter: nil) ?? (isRTL ? "طبيب بيطري" : "Veterinarian"))
            : rawTitle

        self.isCompany = content.isCompany
        if content.isCompany {
            self.typeTitle = Language.get("pet_care_vet_verified_clinic", alter: nil) ?? (isRTL ? "منشأة بيطرية معتمدة" : "Accredited Clinic")
        } else {
            self.typeTitle = Language.get("pet_care_vet_verified_doctor", alter: nil) ?? (isRTL ? "طبيب بيطري معتمد" : "Certified Doctor")
        }

        self.logoURL = content.logoURL.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawBio = content.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bio = rawBio.isEmpty
            ? (Language.get("pet_care_vet_default_subtitle", alter: nil) ?? (isRTL ? "طبيب بيطري معتمد لتقديم استشارات وتشخيصات شاملة للأليف." : "Certified care provider ready for comprehensive pet diagnosis and treatment."))
            : rawBio

        let currency = Language.get("pet_care_vet_currency", alter: nil) ?? (isRTL ? "ر.ق" : "QAR")
        if content.vetCost <= 0.0 {
            self.isFreeConsult = true
            self.consultationCostText = Language.get("pet_care_vet_free_consult", alter: nil) ?? (isRTL ? "استشارة مجانية" : "Free Consultation")
        } else {
            self.isFreeConsult = false
            let numFormatted = PPVetViewerSnapshot.formatNumber(content.vetCost, isRTL: isRTL)
            self.consultationCostText = "\(numFormatted) \(currency)"
        }

        self.isReadyToContact = content.readyToContact
        if content.readyToContact {
            self.statusTitle = Language.get("pet_care_vet_immediate_consult", alter: nil) ?? (isRTL ? "متاح للاستشارة الفورية" : "Available for Instant Consultation")
            self.readinessDetail = Language.get("pet_care_vet_response_fast", alter: nil) ?? (isRTL ? "استجابة فورية" : "Instant Response")
        } else {
            self.statusTitle = Language.get("pet_care_vet_scheduled_only", alter: nil) ?? (isRTL ? "حسب المواعيد المتاحة" : "By Appointment")
            self.readinessDetail = Language.get("pet_care_vet_response_normal", alter: nil) ?? (isRTL ? "استجابة معتادة" : "Standard Response")
        }

        let phoneClean = content.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let whatsappClean = content.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phone = phoneClean
        self.whatsapp = whatsappClean
        self.canCall = !phoneClean.isEmpty || !whatsappClean.isEmpty
        self.canWhatsApp = !whatsappClean.isEmpty || !phoneClean.isEmpty

        let verStatus = content.verificationStatus.lowercased()
        self.isVerified = verStatus == "verified" || verStatus == "approved" || content.subscriptionActive

        if content.subscriptionTier > 0 {
            let format = Language.get("pet_care_vet_viewer_subscription_tier_format", alter: nil) ?? (isRTL ? "باقة %ld معتمدة" : "Tier %ld Accredited")
            self.membershipText = String(format: format, content.subscriptionTier)
        } else if content.subscriptionActive {
            self.membershipText = Language.get("pet_care_vet_viewer_subscription_active", alter: nil) ?? (isRTL ? "عضوية نشطة" : "Active Member")
        } else {
            self.membershipText = Language.get("pet_care_vet_experience_badge", alter: nil) ?? (isRTL ? "خبرة معتمدة" : "Certified Specialist")
        }

        self.availableDateText = content.availableDateText.trimmingCharacters(in: .whitespacesAndNewlines)

        var species: [PPVetSpeciesItem] = []
        for animal in content.animalTypes {
            let item = PPVetSpeciesItem.resolve(from: animal, isRTL: isRTL)
            if !species.contains(where: { $0.id == item.id }) {
                species.append(item)
            }
        }
        if species.isEmpty && !content.mainKindName.isEmpty {
            species.append(PPVetSpeciesItem.resolve(from: content.mainKindName, isRTL: isRTL))
        }
        self.speciesList = species
    }

    private static func formatNumber(_ value: Double, isRTL: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: isRTL ? "ar" : "en")
        formatter.numberStyle = .decimal
        if value.truncatingRemainder(dividingBy: 1.0) == 0 {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

// MARK: - Main Screen View
struct PPVetViewerScreen: View {
    @ObservedObject var presentation: PPVetViewerPresentation
    let onCall: () -> Void
    let onWhatsApp: () -> Void
    let onShare: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseBeacon: Bool = false

    private var isDark: Bool { colorScheme == .dark }
    private var snapshot: PPVetViewerSnapshot { presentation.snapshot }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background base
            Color.ppBackground
                .ignoresSafeArea()

            // Subtle Sanctuary Atmospheric Glow at Top
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.ppCareAccent.opacity(isDark ? 0.22 : 0.12),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 240
                        )
                    )
                    .frame(width: 480, height: 320)
                    .blur(radius: 40)
                    .offset(y: -120)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PPSpace.xl) {
                    // Top Navigation Bar
                    topNavBar

                    // Sanctuary Hero Card
                    heroCard

                    // Clinical Bento Highlights
                    bentoGrid

                    // Species Care Scope
                    if !snapshot.speciesList.isEmpty {
                        speciesCareSection
                    }

                    // Biography & Clinical Credentials
                    bioSection

                    // Emergency Advisory Sanctuary Card
                    emergencyAdvisoryCard

                    // Available Hours (if specified)
                    if !snapshot.availableDateText.isEmpty {
                        availabilityCard
                    }

                    // Bottom Breathing Space for Floating Decision Dock
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, PPSpace.screenMargin)
                .padding(.top, PPSpace.sm)
                .frame(maxWidth: 680)
            }

            // Floating Frosted Decision Dock
            floatingActionDock
                .padding(.horizontal, PPSpace.base)
                .padding(.bottom, PPSpace.sm)
        }
        .environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: snapshot.languageCode))
        .onAppear {
            if snapshot.isReadyToContact {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseBeacon = true
                }
            }
        }
    }

    // MARK: - Navigation Bar
    private var topNavBar: some View {
        HStack {
            // Dismiss / Back Button
            Button(action: onDismiss) {
                Image(systemName: snapshot.isRTL ? "chevron.right" : "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .ppElevatedSurface))
                            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 8, x: 0, y: 3)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.ppSurfaceBorder.opacity(0.8), lineWidth: 0.8)
                    )
            }
            .accessibilityLabel(snapshot.isRTL ? "رجوع" : "Back")

            Spacer()

            // Header Title
            Text(snapshot.isRTL ? "الملف الطبي البيطري" : "Veterinary Profile")
                .font(customFont(17, bold: true, relativeTo: .headline))
                .foregroundStyle(Color.ppTextPrimary)

            Spacer()

            // Share Button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ppTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .ppElevatedSurface))
                            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 8, x: 0, y: 3)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.ppSurfaceBorder.opacity(0.8), lineWidth: 0.8)
                    )
            }
            .accessibilityLabel(snapshot.isRTL ? "مشاركة الملف" : "Share Profile")
        }
        .padding(.vertical, 4)
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: PPSpace.base) {
            // Portrait Avatar
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if !snapshot.logoURL.isEmpty {
                        AppRemoteImage(
                            urlString: snapshot.logoURL,
                            displaySize: CGSize(width: 86, height: 86),
                            contentMode: .fill
                        )
                    } else {
                        ZStack {
                            Color.ppCareAccent.opacity(isDark ? 0.18 : 0.10)
                            Image(systemName: snapshot.isCompany ? "cross.case.fill" : "stethoscope")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(Color.ppCareAccent)
                        }
                    }
                }
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.ppSurfaceBorder, lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.25 : 0.08), radius: 16, x: 0, y: 6)

                // Verification Shield Badge
                if snapshot.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(red: 0.15, green: 0.68, blue: 0.38))
                        .background(
                            Circle()
                                .fill(Color(uiColor: .ppElevatedSurface))
                                .frame(width: 24, height: 24)
                        )
                        .offset(x: snapshot.isRTL ? -4 : 4, y: 4)
                }
            }
            .padding(.top, 4)

            // Titles
            VStack(spacing: 6) {
                Text(snapshot.title)
                    .font(customFont(25, bold: true, relativeTo: .title2))
                    .foregroundStyle(Color.ppTextPrimary)
                    .multilineTextAlignment(.center)

                Text(snapshot.typeTitle)
                    .font(customFont(14.5, bold: false, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppCareAccent)
            }

            // Live On-Duty Pill
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            (snapshot.isReadyToContact
                             ? Color(red: 0.13, green: 0.80, blue: 0.45)
                             : Color.orange).opacity(pulseBeacon ? 0.35 : 0.12)
                        )
                        .frame(width: 16, height: 16)
                        .scaleEffect(pulseBeacon ? 1.35 : 0.9)

                    Circle()
                        .fill(snapshot.isReadyToContact ? Color(red: 0.13, green: 0.80, blue: 0.45) : Color.orange)
                        .frame(width: 8, height: 8)
                }

                Text(snapshot.statusTitle)
                    .font(customFont(13, bold: true, relativeTo: .footnote))
                    .foregroundStyle(snapshot.isReadyToContact ? Color(red: 0.13, green: 0.80, blue: 0.45) : Color.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill((snapshot.isReadyToContact ? Color(red: 0.13, green: 0.80, blue: 0.45) : Color.orange).opacity(isDark ? 0.18 : 0.08))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        (snapshot.isReadyToContact ? Color(red: 0.13, green: 0.80, blue: 0.45) : Color.orange).opacity(0.24),
                        lineWidth: 0.8
                    )
            )
        }
        .padding(.vertical, PPSpace.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(Color(uiColor: .ppElevatedSurface))
                .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.04), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.4 : 0.8), lineWidth: 0.8)
        )
    }

    // MARK: - Bento Grid (3-pillar insights)
    private var bentoGrid: some View {
        HStack(spacing: PPSpace.md) {
            // Card 1: Fee
            bentoCard(
                icon: "creditcard.fill",
                title: snapshot.isRTL ? "رسوم الكشف" : "Consult Fee",
                value: snapshot.consultationCostText,
                tintColor: snapshot.isFreeConsult ? Color(red: 0.15, green: 0.68, blue: 0.38) : Color.ppCareAccent
            )

            // Card 2: Readiness
            bentoCard(
                icon: "bolt.shield.fill",
                title: snapshot.isRTL ? "الجاهزية" : "Readiness",
                value: snapshot.readinessDetail,
                tintColor: Color(red: 0.18, green: 0.65, blue: 0.55)
            )

            // Card 3: Membership / Tier
            bentoCard(
                icon: "checkmark.shield.fill",
                title: snapshot.isRTL ? "الاعتماد" : "Status",
                value: snapshot.membershipText,
                tintColor: Color(red: 0.85, green: 0.55, blue: 0.15)
            )
        }
    }

    private func bentoCard(icon: String, title: String, value: String, tintColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tintColor)
                .padding(7)
                .background(
                    Circle()
                        .fill(tintColor.opacity(isDark ? 0.18 : 0.10))
                )

            Spacer(minLength: 4)

            Text(title)
                .font(customFont(11.5, bold: false, relativeTo: .caption2))
                .foregroundStyle(Color.ppTextSecondary)
                .lineLimit(1)

            Text(value)
                .font(customFont(13.5, bold: true, relativeTo: .subheadline))
                .foregroundStyle(Color.ppTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 106)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .fill(Color(uiColor: .ppElevatedSurface))
                .shadow(color: Color.black.opacity(isDark ? 0.15 : 0.03), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.medium, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.35 : 0.75), lineWidth: 0.8)
        )
    }

    // MARK: - Species Scope Section
    private var speciesCareSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ppCareAccent)

                Text(snapshot.isRTL ? "الحيوانات المشمولة بالرعاية" : "Specialized Care Scope")
                    .font(customFont(16, bold: true, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(snapshot.speciesList) { item in
                    HStack(spacing: 7) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.ppCareAccent)

                        Text(item.name)
                            .font(customFont(13, bold: false, relativeTo: .subheadline))
                            .foregroundStyle(Color.ppTextPrimary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.ppSecondarySurface)
                    )
                }
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(Color(uiColor: .ppElevatedSurface))
                .shadow(color: Color.black.opacity(isDark ? 0.15 : 0.03), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.35 : 0.75), lineWidth: 0.8)
        )
    }

    // MARK: - Biography & Credentials
    private var bioSection: some View {
        VStack(alignment: .leading, spacing: PPSpace.md) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ppCareAccent)

                Text(snapshot.isCompany
                     ? (snapshot.isRTL ? "عن المركز والخدمات الطبية" : "About Clinic & Services")
                     : (snapshot.isRTL ? "نبذة عن الطبيب والخبرات" : "About Doctor & Experience"))
                    .font(customFont(16, bold: true, relativeTo: .headline))
                    .foregroundStyle(Color.ppTextPrimary)
            }

            Text(snapshot.bio)
                .font(customFont(15, bold: false, relativeTo: .body))
                .foregroundStyle(Color.ppTextPrimary.opacity(0.88))
                .lineSpacing(5)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(Color(uiColor: .ppElevatedSurface))
                .shadow(color: Color.black.opacity(isDark ? 0.15 : 0.03), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.35 : 0.75), lineWidth: 0.8)
        )
    }

    // MARK: - Emergency Advisory Card
    private var emergencyAdvisoryCard: some View {
        HStack(alignment: .top, spacing: PPSpace.md) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(isDark ? 0.22 : 0.10))
                    .frame(width: 38, height: 38)

                Image(systemName: "cross.case.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.isRTL ? "خدمة الطوارئ والرعاية العاجلة" : "Emergency & Critical Care")
                    .font(customFont(15, bold: true, relativeTo: .headline))
                    .foregroundStyle(Color.red)

                Text(snapshot.isRTL
                     ? "في الحالات الحرجة أو الإصابات المفاجئة، يُرجى الاتصال المباشر على مدار الساعة لتقديم الإسعافات وتوجيهكم للمركز الأنسب."
                     : "In critical cases or sudden emergencies, please call directly 24/7 for immediate first-aid guidance and triage.")
                    .font(customFont(13, bold: false, relativeTo: .footnote))
                    .foregroundStyle(Color.ppTextSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(Color.red.opacity(isDark ? 0.09 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.red.opacity(isDark ? 0.28 : 0.16), lineWidth: 0.8)
        )
    }

    // MARK: - Availability Card
    private var availabilityCard: some View {
        HStack(spacing: PPSpace.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ppCareAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.isRTL ? "مواعيد العمل المتاحة" : "Available Consultation Hours")
                    .font(customFont(12, bold: false, relativeTo: .caption))
                    .foregroundStyle(Color.ppTextSecondary)

                Text(snapshot.availableDateText)
                    .font(customFont(14.5, bold: true, relativeTo: .subheadline))
                    .foregroundStyle(Color.ppTextPrimary)
            }
            Spacer()
        }
        .padding(PPSpace.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .fill(Color(uiColor: .ppElevatedSurface))
                .shadow(color: Color.black.opacity(isDark ? 0.15 : 0.03), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PPCorner.card, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.35 : 0.75), lineWidth: 0.8)
        )
    }

    // MARK: - Floating Frosted Action Dock
    private var floatingActionDock: some View {
        HStack(spacing: PPSpace.sm) {
            // Direct Phone Call Button
            Button(action: onCall) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(snapshot.isRTL ? "اتصال هاتفي" : "Direct Call")
                        .font(customFont(15, bold: true, relativeTo: .headline))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(snapshot.canCall ? Color.ppCareAccent : Color.gray)
                        .shadow(color: snapshot.canCall ? Color.ppCareAccent.opacity(0.35) : Color.clear, radius: 10, x: 0, y: 4)
                )
            }
            .buttonStyle(PPScaleButtonStyle())
            .disabled(!snapshot.canCall)
            .accessibilityLabel(snapshot.isRTL ? "اتصال هاتفي مباشر" : "Direct phone call")

            // Direct WhatsApp Consultation Button
            Button(action: onWhatsApp) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(snapshot.isRTL ? "محادثة واتساب" : "WhatsApp")
                        .font(customFont(15, bold: true, relativeTo: .headline))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(snapshot.canWhatsApp ? Color(red: 0.15, green: 0.68, blue: 0.38) : Color.gray)
                        .shadow(color: snapshot.canWhatsApp ? Color(red: 0.15, green: 0.68, blue: 0.38).opacity(0.35) : Color.clear, radius: 10, x: 0, y: 4)
                )
            }
            .buttonStyle(PPScaleButtonStyle())
            .disabled(!snapshot.canWhatsApp)
            .accessibilityLabel(snapshot.isRTL ? "محادثة واتساب فورية" : "Instant WhatsApp consultation")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .ppElevatedSurface).opacity(isDark ? 0.92 : 0.88))
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.10), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.ppSurfaceBorder.opacity(isDark ? 0.45 : 0.8), lineWidth: 0.8)
        )
    }

    private func customFont(_ size: CGFloat, bold: Bool = false, relativeTo style: Font.TextStyle) -> Font {
        .custom(bold ? "Beiruti-Bold" : "Beiruti-Regular", size: size, relativeTo: style)
    }
}

// MARK: - Scale Button Style
private struct PPScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
