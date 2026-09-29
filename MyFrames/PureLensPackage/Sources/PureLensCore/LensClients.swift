import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct LensResolver: Sendable {
    public var resolve: @Sendable (LensResolveRequest) async throws -> LensInsight

    public init(resolve: @escaping @Sendable (LensResolveRequest) async throws -> LensInsight) {
        self.resolve = resolve
    }
}

public struct LensContextClient: Sendable {
    public var current: @Sendable () async throws -> LensContext

    public init(current: @escaping @Sendable () async throws -> LensContext) {
        self.current = current
    }

    public static func constant(_ context: LensContext) -> Self {
        Self(current: { context })
    }
}

@MainActor
public struct LensActionClient {
    public var perform: @MainActor (LensAction) async throws -> LensActionReceipt

    public init(perform: @escaping @MainActor (LensAction) async throws -> LensActionReceipt) {
        self.perform = perform
    }
}

public struct LensAnalyticsClient: Sendable {
    public var track: @Sendable (_ name: String, _ properties: [String: String]) -> Void

    public init(track: @escaping @Sendable (_ name: String, _ properties: [String: String]) -> Void) {
        self.track = track
    }

    public static let none = Self { _, _ in }
}

@MainActor
public struct LensDiscoveryClient {
    /// Optional server-assisted animal identity refinement. The selected frame is uploaded only after consent.
    public var identifyAnimal: (@MainActor (LensFrame, DetectedAnimalContext) async throws -> LensAnimalIdentificationResult)?
    /// Rechecks a user-selected uncertain candidate on the original consented frame.
    /// This must call the server; the selected name never grants commerce access locally.
    public var confirmAnimalCandidate: (@MainActor (LensFrame, DetectedAnimalContext, String) async throws -> LensAnimalIdentificationResult)?
    /// Canonical live taxonomy resolver. A positive commerce path requires the returned mainKindID.
    public var resolveAnimalSupport: (@MainActor (DetectedAnimalContext) async throws -> LensAnimalSupportContext?)?
    /// Legacy compatibility signal. `true` alone must never authorize commerce.
    public var isAnimalSupported: @MainActor (
        _ animal: DetectedAnimalContext
    ) async throws -> Bool
    public var searchByImage: @MainActor (
        _ frame: LensFrame,
        _ animal: DetectedAnimalContext
    ) async throws -> LensImageSearchResult
    public var searchMarketplace: @MainActor (
        _ category: LensDiscoveryCategory,
        _ animal: DetectedAnimalContext
    ) async throws -> [LensDiscoveryItem]

    public init(
        identifyAnimal: (@MainActor (LensFrame, DetectedAnimalContext) async throws -> LensAnimalIdentificationResult)? = nil,
        confirmAnimalCandidate: (@MainActor (LensFrame, DetectedAnimalContext, String) async throws -> LensAnimalIdentificationResult)? = nil,
        resolveAnimalSupport: (@MainActor (DetectedAnimalContext) async throws -> LensAnimalSupportContext?)? = nil,
        isAnimalSupported: @escaping @MainActor (
            _ animal: DetectedAnimalContext
        ) async throws -> Bool = { _ in true },
        searchByImage: @escaping @MainActor (
            _ frame: LensFrame,
            _ animal: DetectedAnimalContext
        ) async throws -> LensImageSearchResult,
        searchMarketplace: @escaping @MainActor (
            _ category: LensDiscoveryCategory,
            _ animal: DetectedAnimalContext
        ) async throws -> [LensDiscoveryItem]
    ) {
        self.identifyAnimal = identifyAnimal
        self.confirmAnimalCandidate = confirmAnimalCandidate
        self.resolveAnimalSupport = resolveAnimalSupport
        self.isAnimalSupported = isAnimalSupported
        self.searchByImage = searchByImage
        self.searchMarketplace = searchMarketplace
    }
}

@MainActor
public struct LensDiscoveryActionClient {
    public var open: @MainActor (_ item: LensDiscoveryItem) async throws -> Void

    public init(
        open: @escaping @MainActor (_ item: LensDiscoveryItem) async throws -> Void
    ) {
        self.open = open
    }
}

@MainActor
public struct LensGuidanceActionClient {
    public var open: @MainActor (_ handoff: LensGuidanceHandoff) -> Void

    public init(
        open: @escaping @MainActor (_ handoff: LensGuidanceHandoff) -> Void
    ) {
        self.open = open
    }
}

public enum LensHTTPError: Error, Equatable, LocalizedError, Sendable {
    case insecureEndpoint
    case invalidAdditionalHeaders
    case invalidResponse
    case unauthorized
    case rateLimited
    case noResult
    case staleContext
    case requestTooLarge
    case responseTooLarge
    case server(statusCode: Int)
    case decoding

    public var errorDescription: String? {
        switch self {
        case .insecureEndpoint:
            return "Pure Lens requires an HTTPS endpoint."
        case .invalidAdditionalHeaders:
            return "Pure Lens received invalid additional request headers."
        case .invalidResponse:
            return "Pure Lens received an invalid server response."
        case .unauthorized:
            return "Pure Lens authentication failed."
        case .rateLimited:
            return "Pure Lens is temporarily busy."
        case .noResult:
            return "Pure Lens could not find a safe, reliable result."
        case .staleContext:
            return "Pure Lens context changed and must be refreshed."
        case .requestTooLarge:
            return "The selected Pure Lens frame is too large."
        case .responseTooLarge:
            return "Pure Lens received an oversized response."
        case .server(let statusCode):
            return "Pure Lens server error (\(statusCode))."
        case .decoding:
            return "Pure Lens could not understand the server response."
        }
    }
}

public extension LensResolver {
    @available(macOS 12.0, *)
    static func http(
        endpoint: URL,
        session: URLSession = .shared,
        requestTimeout: TimeInterval = 15,
        additionalHeadersProvider: @escaping @Sendable () async throws -> [String: String] = { [:] },
        tokenProvider: @escaping @Sendable () async throws -> String
    ) -> Self {
        Self { requestValue in
            guard endpoint.scheme?.lowercased() == "https", endpoint.host != nil else {
                throw LensHTTPError.insecureEndpoint
            }
            if let frame = requestValue.frame, frame.data.count > 4_000_000 {
                throw LensHTTPError.requestTooLarge
            }
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = min(max(5, requestTimeout), 30)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(requestValue.context.localeIdentifier, forHTTPHeaderField: "Accept-Language")
            request.setValue(requestValue.id, forHTTPHeaderField: "Idempotency-Key")

            let token = try await tokenProvider()
            guard !token.isEmpty,
                  token.count <= 8_192,
                  !token.contains("\n"),
                  !token.contains("\r")
            else {
                throw LensHTTPError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let additionalHeaders = try await additionalHeadersProvider()
            let protectedHeaders = ["authorization", "content-type", "accept", "accept-language", "idempotency-key"]
            guard additionalHeaders.count <= 16,
                  additionalHeaders.allSatisfy({ key, value in
                      !protectedHeaders.contains(key.lowercased())
                          && !key.isEmpty
                          && key.count <= 128
                          && value.count <= 2_048
                          && !key.contains("\n")
                          && !key.contains("\r")
                          && !value.contains("\n")
                          && !value.contains("\r")
                  })
            else {
                throw LensHTTPError.invalidAdditionalHeaders
            }
            additionalHeaders.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let body = try encoder.encode(requestValue)
            guard body.count <= 6_000_000 else {
                throw LensHTTPError.requestTooLarge
            }
            request.httpBody = body

            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw LensHTTPError.invalidResponse
            }

            switch response.statusCode {
            case 200..<300:
                break
            case 401, 403:
                throw LensHTTPError.unauthorized
            case 429:
                throw LensHTTPError.rateLimited
            case 409:
                throw LensHTTPError.staleContext
            case 422:
                throw LensHTTPError.noResult
            default:
                throw LensHTTPError.server(statusCode: response.statusCode)
            }

            guard data.count <= 1_000_000 else {
                throw LensHTTPError.responseTooLarge
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let insight = try? decoder.decode(LensInsight.self, from: data) else {
                throw LensHTTPError.decoding
            }
            return insight
        }
    }
}
