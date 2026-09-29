#if canImport(UIKit)
import Foundation
import PureLensCore

@MainActor
public struct PureLensModule {
    public var configuration: PureLensConfiguration
    public var theme: PureLensTheme
    public var discovery: LensDiscoveryClient
    public var discoveryActions: LensDiscoveryActionClient
    public var guidanceActions: LensGuidanceActionClient?
    public var analytics: LensAnalyticsClient
    public var coreMLDetector: PureLensCoreMLDetector?

    public init(
        configuration: PureLensConfiguration = .production,
        theme: PureLensTheme = .purePets,
        discovery: LensDiscoveryClient,
        discoveryActions: LensDiscoveryActionClient,
        guidanceActions: LensGuidanceActionClient? = nil,
        analytics: LensAnalyticsClient = .none,
        coreMLDetector: PureLensCoreMLDetector? = nil
    ) {
        self.configuration = configuration
        self.theme = theme
        self.discovery = discovery
        self.discoveryActions = discoveryActions
        self.guidanceActions = guidanceActions
        self.analytics = analytics
        self.coreMLDetector = coreMLDetector
    }

    public static func production(
        configuration: PureLensConfiguration = .production,
        theme: PureLensTheme = .purePets,
        discovery: LensDiscoveryClient,
        actionHandler: @escaping @MainActor (LensDiscoveryItem) async throws -> Void,
        guidanceActions: LensGuidanceActionClient? = nil,
        analytics: LensAnalyticsClient = .none,
        coreMLDetector: PureLensCoreMLDetector? = nil
    ) -> Self {
        Self(
            configuration: configuration,
            theme: theme,
            discovery: discovery,
            discoveryActions: LensDiscoveryActionClient(open: actionHandler),
            guidanceActions: guidanceActions,
            analytics: analytics,
            coreMLDetector: coreMLDetector
        )
    }

    public static let demo = demo(localeIdentifier: nil)

    /// Deterministic package preview. The legacy context closure is retained
    /// for source compatibility and is never evaluated by discovery.
    public static func purePetsCameraPreview(
        localeIdentifier: String? = nil,
        contextProvider: @escaping @Sendable () async throws -> LensContext
    ) -> Self {
        _ = contextProvider
        return demo(localeIdentifier: localeIdentifier)
    }

    public static func demo(localeIdentifier: String?) -> Self {
        var configuration = PureLensConfiguration.demo
        configuration.localeIdentifier = localeIdentifier
        let demoMainKindID = 3

        return Self(
            configuration: configuration,
            discovery: LensDiscoveryClient(
                resolveAnimalSupport: { _ in
                    LensAnimalSupportContext(
                        mainKindID: demoMainKindID,
                        nameEn: "Dogs",
                        nameAr: "كلاب",
                        matchedBy: "demo"
                    )
                },
                searchByImage: { _, animal in
                    LensImageSearchResult(
                        items: [
                            LensDiscoveryItem(
                                id: "demo-accessory",
                                category: .accessories,
                                kind: .accessory,
                                title: LensL10n.string(
                                    "lens.demo.discovery.accessory",
                                    localeIdentifier: localeIdentifier
                                ),
                                source: .imageSearch,
                                petMainKindID: demoMainKindID,
                                visualScore: 0.92,
                                metadata: ["species": animal.species]
                            )
                        ]
                    )
                },
                searchMarketplace: { category, animal in
                    let key = "lens.demo.discovery.\(category.rawValue)"
                    let kind: LensDiscoveryItemKind
                    switch category {
                    case .accessories: kind = .accessory
                    case .services: kind = .service
                    case .medicine: kind = .medicine
                    case .products: kind = .product
                    }
                    return [
                        LensDiscoveryItem(
                            id: "demo-\(category.rawValue)",
                            category: category,
                            kind: kind,
                            title: LensL10n.string(key, localeIdentifier: localeIdentifier),
                            source: .marketplaceTaxonomy,
                            petMainKindID: demoMainKindID,
                            metadata: ["species": animal.species]
                        )
                    ]
                }
            ),
            discoveryActions: LensDiscoveryActionClient(open: { _ in })
        )
    }
}

enum LensL10n {
    static func string(_ key: String, localeIdentifier: String? = nil) -> String {
        NSLocalizedString(
            key,
            bundle: localizedBundle(for: localeIdentifier),
            value: key,
            comment: ""
        )
    }

    static func format(
        _ key: String,
        _ argument: CVarArg,
        localeIdentifier: String? = nil
    ) -> String {
        format(
            key,
            arguments: [argument],
            localeIdentifier: localeIdentifier
        )
    }

    static func format(
        _ key: String,
        arguments: [CVarArg],
        localeIdentifier: String? = nil
    ) -> String {
        let locale = localeIdentifier.map(Locale.init(identifier:)) ?? Locale.current
        return String(
            format: string(key, localeIdentifier: localeIdentifier),
            locale: locale,
            arguments: arguments
        )
    }

    private static func localizedBundle(for localeIdentifier: String?) -> Bundle {
        guard let localeIdentifier, !localeIdentifier.isEmpty else {
            return .module
        }
        let canonical = Locale.canonicalLanguageIdentifier(from: localeIdentifier)
        let language = canonical.split(separator: "-").first.map(String.init)
        let candidates = [canonical, language].compactMap { $0 }
        for candidate in candidates {
            if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .module
    }
}

#endif
