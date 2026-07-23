import Foundation

/// Immutable, presentation-ready projection of a `PetAd`.
///
/// The snapshot is the single source of truth for the screen's static
/// content. It is rebuilt when localization changes so every formatted
/// string flows through the legacy formatting layer exactly once.
struct PPPetAdViewerSnapshot {
    let ad: PetAd
    let title: String
    let category: String
    let subcategory: String
    let location: String
    let price: String
    let age: String
    let gender: String
    let description: String
    let postedDate: String
    let media: [PPPetAdMediaItem]

    var hasRenderableContent: Bool {
        !title.isEmpty ||
            !category.isEmpty ||
            !subcategory.isEmpty ||
            !price.isEmpty ||
            !age.isEmpty ||
            !gender.isEmpty ||
            !description.isEmpty ||
            !media.isEmpty
    }

    /// Category · Subcategory breadcrumb, omitting empty segments.
    var categoryLine: String {
        [category, subcategory]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// The factual type label used by the info grid — prefers the
    /// more specific subcategory when one exists.
    var typeLabel: String {
        subcategory.isEmpty ? category : subcategory
    }

    /// Normalized description with blank runs collapsed into paragraphs.
    var normalizedDescription: String {
        description
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
