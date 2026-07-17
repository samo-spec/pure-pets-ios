import SwiftUI
import PurePetsLayoutKit

struct MarketplaceItem: Identifiable {
    let id: String
    let title: String
    let imageURL: URL?
    let imageRatio: CGFloat
}

struct PurePetsMarketplaceLayoutExample: View {
    @State private var mode: PPLayoutMode = .pinterest
    let items: [MarketplaceItem]

    var body: some View {
        NavigationStack {
            PPLayoutContainer(
                items: items,
                mode: mode,
                descriptor: { item in
                    PPLayoutItemDescriptor(
                        id: item.id,
                        imageAspectRatio: item.imageRatio,
                        estimatedBodyHeight: 94,
                        titleLineCount: item.title.count > 34 ? 2 : 1
                    )
                }
            ) { item in
                PPPremiumCardSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        PPAsyncMediaSurface(
                            url: item.imageURL,
                            aspectRatio: item.imageRatio
                        ) {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                    }
                }
            }
            .navigationTitle("Marketplace")
            .toolbar {
                Menu("Layout") {
                    ForEach(PPLayoutMode.allCases, id: \.rawValue) { value in
                        Button(String(describing: value)) { mode = value }
                    }
                }
            }
        }
    }
}
