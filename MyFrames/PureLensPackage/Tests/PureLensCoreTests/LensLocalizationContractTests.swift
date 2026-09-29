import Foundation
import XCTest

final class LensLocalizationContractTests: XCTestCase {
    func testArabicAndEnglishContainSameTerminalIdentityKeys() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let resources = root.appendingPathComponent("Sources/PureLens/Resources")
        let englishKeys = try keys(in: resources.appendingPathComponent("en.lproj/Localizable.strings"))
        let arabicKeys = try keys(in: resources.appendingPathComponent("ar.lproj/Localizable.strings"))
        let required: Set<String> = [
            "lens.prompt.unsupported",
            "lens.prompt.unsupported.detail",
            "lens.prompt.uncertain",
            "lens.prompt.not_animal",
            "lens.prompt.not_animal.detail",
            "lens.prompt.taxonomy_unavailable",
            "lens.prompt.taxonomy_unavailable.detail",
            "lens.identity.scientific_name",
            "lens.identity.group",
            "lens.identity.breed",
            "lens.identity.confidence"
        ]
        XCTAssertEqual(englishKeys, arabicKeys)
        XCTAssertTrue(required.isSubset(of: englishKeys))
    }

    private func keys(in url: URL) throws -> Set<String> {
        let text = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"(?m)^"([^\"]+)"\s*="#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[keyRange])
        })
    }
}
