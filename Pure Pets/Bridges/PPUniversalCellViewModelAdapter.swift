import PurePetsLayoutKit

extension PPUniversalCellViewModel {
    var ppLayoutDescriptor: PPLayoutItemDescriptor {
        let ratio: CGFloat? = imageSize.width > 0 && imageSize.height > 0
            ? imageSize.height / imageSize.width
            : nil

        let identifier: String = {
            if let mid = modelID, !mid.isEmpty { return mid }
            return "\(ppSection.rawValue)-\(indexPath?.item ?? 0)"
        }()

        var body: CGFloat = 128
        if modelContext == .forServices || modelContext == .forVets {
            body = 100
        } else if modelContext == .forMarket || modelContext == .forFood {
            body = 148
        }

        return PPLayoutItemDescriptor(
            id: identifier,
            imageAspectRatio: ratio,
            preferredAspectRatio: preferredAspectRatio > 0 ? preferredAspectRatio : nil,
            estimatedBodyHeight: body,
            minimumCardHeight: 130,
            titleLineCount: title.count > 38 ? 2 : 1,
            hasSubtitle: subtitle.count > 0 || location.count > 0,
            hasBadge: subtitle.count > 0
        )
    }
}
