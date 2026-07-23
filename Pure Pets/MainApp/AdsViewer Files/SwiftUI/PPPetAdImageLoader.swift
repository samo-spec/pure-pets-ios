import Combine
import Foundation
import UIKit

@MainActor
final class PPPetAdImageLoader: ObservableObject {
    @Published private(set) var state: PPPetAdImageLoadState = .idle

    private var requestID = UUID()
    private var currentURL: String?

    func load(urlString: String?, blurHash: String?) {
        let normalizedURL =
            urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHash =
            blurHash?.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentURL == normalizedURL,
           case .loaded = state {
            return
        }

        requestID = UUID()
        let activeRequestID = requestID
        currentURL = normalizedURL
        state = .loading(placeholder: nil)

        if let normalizedHash, !normalizedHash.isEmpty {
            PPBlurHashBridge.image(
                from: normalizedHash,
                size: CGSize(width: 40, height: 40),
                punch: 1
            ) { [weak self] placeholder in
                guard let self,
                      self.requestID == activeRequestID else {
                    return
                }
                guard let placeholder else {
                    if normalizedURL?.isEmpty != false {
                        self.state = .idle
                    }
                    return
                }
                if case .loading = self.state {
                    if normalizedURL?.isEmpty == false {
                        self.state = .loading(placeholder: placeholder)
                    } else {
                        self.state = .loaded(placeholder)
                    }
                }
            }
        }

        guard let normalizedURL, !normalizedURL.isEmpty else {
            if normalizedHash?.isEmpty != false {
                state = .idle
            }
            return
        }

        PPPetAdViewerLegacyBridge.loadImage(
            url: normalizedURL
        ) { [weak self] image in
            guard let self, self.requestID == activeRequestID else {
                return
            }
            if let image {
                self.state = .loaded(image)
            } else {
                self.state = .failed
            }
        }
    }

    func retry(blurHash: String?) {
        load(urlString: currentURL, blurHash: blurHash)
    }

    func cancel() {
        requestID = UUID()
    }
}
