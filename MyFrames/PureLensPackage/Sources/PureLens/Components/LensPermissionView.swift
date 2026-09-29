#if canImport(UIKit)
import PureLensCore
import SwiftUI

struct LensPermissionView: View {
    let authorization: LensCameraAuthorization
    let theme: PureLensTheme
    let localeIdentifier: String
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.ambientField, theme.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(theme.brandSoft)
                                .frame(width: 104, height: 104)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(theme.brandStrong)
                        }
                        .accessibilityHidden(true)

                        VStack(spacing: 10) {
                            Text(title)
                                .font(theme.typography.title2)
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.center)
                            Text(detail)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 10) {
                            if authorization == .denied {
                                Button(text("lens.permission.settings"), action: openSettings)
                                    .buttonStyle(.borderedProminent)
                                    .tint(theme.brandStrong)
                                    .font(theme.typography.headline)
                                    .controlSize(.large)
                            }
                            Button(text("lens.close"), action: dismiss)
                                .buttonStyle(.bordered)
                                .tint(theme.textPrimary)
                                .font(theme.typography.headline)
                                .controlSize(.large)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .lensScrollIndicatorsHidden()
            }
        }
    }

    private var title: String {
        switch authorization {
        case .notDetermined:
            return text("lens.permission.requesting")
        case .denied:
            return text("lens.permission.denied.title")
        case .restricted:
            return text("lens.permission.restricted.title")
        case .unavailable:
            return text("lens.permission.unavailable.title")
        case .authorized:
            return ""
        }
    }

    private var detail: String {
        switch authorization {
        case .notDetermined:
            return text("lens.permission.requesting.detail")
        case .denied:
            return text("lens.permission.denied.detail")
        case .restricted:
            return text("lens.permission.restricted.detail")
        case .unavailable:
            return text("lens.permission.unavailable.detail")
        case .authorized:
            return ""
        }
    }

    private func text(_ key: String) -> String {
        LensL10n.string(key, localeIdentifier: localeIdentifier)
    }
}


#endif
