import Combine
import SwiftUI

struct PPPetAdViewerNavigationRoot: View {
    let ad: PetAd
    let repository: PPPetAdViewerRepository
    let hostActions: PPPetAdViewerHostActions

    @State private var isRightToLeft = Language.isRTL()
    @State private var languageCode: String =
        Language.currentLanguageCode() ?? "en"
    @State private var authenticationRevision = UUID()

    var body: some View {
        NavigationView {
            PPPetAdViewerScreen(
                ad: ad,
                repository: repository,
                hostActions: hostActions,
                isRoot: true,
                languageCode: languageCode,
                authenticationRevision: authenticationRevision
            )
        }
        .navigationViewStyle(.stack)
        .environment(
            \.layoutDirection,
            isRightToLeft ? .rightToLeft : .leftToRight
        )
        .environment(
            \.locale,
            Locale(identifier: languageCode)
        )
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "LanguageDidChangeNotification"
                )
            )
        ) { _ in
            updateLanguage()
        }
        .onReceive(authenticationEvents) { _ in
            authenticationRevision = UUID()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name(
                    "PPLanguageDidChangeNotification"
                )
            )
        ) { _ in
            updateLanguage()
        }
    }

    private func updateLanguage() {
        isRightToLeft = Language.isRTL()
        languageCode = Language.currentLanguageCode() ?? "en"
    }

    private var authenticationEvents:
        AnyPublisher<Notification, Never> {
        let names = [
            "PPUserManagerDidSyncCurrentUserNotification",
            "PPUserManagerDidSignOutNotification",
            "PPUserManagerDidUpdateBlockedStateNotification",
            "PPUserManagerDidUpdateUserAccessNotification"
        ]
        return Publishers.MergeMany(
            names.map {
                NotificationCenter.default.publisher(
                    for: Notification.Name($0)
                )
            }
        )
        .eraseToAnyPublisher()
    }
}
