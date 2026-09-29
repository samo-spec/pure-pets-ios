import Foundation
import XCTest
@testable import PureLensCore

final class LensHTTPClientTests: XCTestCase {
    func testMissingPetProfileDoesNotCreateAClientSideEligibilityError() async {
        let resolver = LensResolver.http(
            endpoint: URL(string: "https://example.com/lens")!,
            tokenProvider: { "" }
        )
        let request = LensResolveRequest(
            frame: nil,
            localDetections: [],
            context: LensContext()
        )
        await assertHTTPError(.unauthorized, from: resolver, request: request)
    }

    func testRejectsInsecureEndpointBeforeNetwork() async {
        let resolver = LensResolver.http(
            endpoint: URL(string: "http://example.com/lens")!,
            tokenProvider: { "token" }
        )
        await assertHTTPError(.insecureEndpoint, from: resolver)
    }

    func testRejectsProtectedAdditionalHeader() async {
        let resolver = LensResolver.http(
            endpoint: URL(string: "https://example.com/lens")!,
            additionalHeadersProvider: { ["Authorization": "replacement"] },
            tokenProvider: { "token" }
        )
        await assertHTTPError(.invalidAdditionalHeaders, from: resolver)
    }

    func testRejectsOversizedFrameBeforeNetwork() async {
        let resolver = LensResolver.http(
            endpoint: URL(string: "https://example.com/lens")!,
            tokenProvider: { "token" }
        )
        let request = LensResolveRequest(
            frame: LensFrame(
                data: Data(repeating: 0, count: 4_000_001),
                pixelWidth: 1_024,
                pixelHeight: 1_024
            ),
            localDetections: [],
            context: LensContext(activePetID: "test-pet")
        )
        await assertHTTPError(.requestTooLarge, from: resolver, request: request)
    }

    private func assertHTTPError(
        _ expected: LensHTTPError,
        from resolver: LensResolver,
        request: LensResolveRequest = LensResolveRequest(
            frame: nil,
            localDetections: [],
            context: LensContext(activePetID: "test-pet")
        ),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await resolver.resolve(request)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? LensHTTPError, expected, file: file, line: line)
        }
    }
}
