import Foundation
import UIKit
import HXPhotoPicker

// MARK: - PPPhotoBrowserBridge

@objc public class PPPhotoBrowserBridge: NSObject {

    @objc public var useArabic: Bool = false

    private weak var observedBrowser: PhotoBrowser?
    private var isObservingPageIndex = false
    private weak var pageLabel: UILabel?
    private var totalAssetCount: Int = 0
    private let core = PPCoreBridge()

    public override init() {
        super.init()
    }

    // MARK: - Public Entry (UIImage array)

    @objc(showBrowserFrom:images:startIndex:)
    public func showBrowser(
        from vc: UIViewController,
        images: [UIImage],
        startIndex: Int
    ) {
        core.useArabic = useArabic
        let assets = core.convertImagesToAssets(images)
        presentBrowser(from: vc, assets: assets, startIndex: startIndex)
    }

    // MARK: - Public Entry (URL strings)

    @objc(showBrowserFrom:imageURLStrings:startIndex:)
    public func showBrowser(
        from vc: UIViewController,
        imageURLStrings: [String],
        startIndex: Int
    ) {
        core.useArabic = useArabic

        let assets: [PhotoAsset] = imageURLStrings.compactMap {
            guard let url = URL(string: $0) else { return nil }
            let net = NetworkImageAsset(thumbnailURL: url, originalURL: url)
            return PhotoAsset(networkImageAsset: net)
        }

        guard !assets.isEmpty else { return }
        presentBrowser(from: vc, assets: assets, startIndex: startIndex)
    }

    // MARK: - Internal Browser Launcher

    private func presentBrowser(
        from vc: UIViewController,
        assets: [PhotoAsset],
        startIndex: Int
    ) {
        var config = PhotoBrowser.Configuration()
        config.tintColor = .black
        config.backgroundColor = .white
        config.modalPresentationStyle = .fullScreen
        config.showDelete = false

        totalAssetCount = assets.count

        PhotoManager.shared.createLanguageBundle(
            languageType: useArabic ? .arabic : .english
        )

        let browser = PhotoBrowser(config, pageIndex: startIndex, assets: assets)
        addPageIndicator(to: browser, totalCount: assets.count, startIndex: startIndex)

        vc.present(browser, animated: true) { [weak self, weak browser] in
            guard let self = self, let browser = browser else { return }

            browser.view.setNeedsLayout()
            browser.view.layoutIfNeeded()
            browser.pageIndex = startIndex

            self.removePageIndexObserverIfNeeded()
            self.observedBrowser = browser
            browser.addObserver(self, forKeyPath: "pageIndex", options: [.new], context: nil)
            self.isObservingPageIndex = true
        }
    }

    deinit {
        removePageIndexObserverIfNeeded()
    }

    private func removePageIndexObserverIfNeeded() {
        if let browser = observedBrowser, isObservingPageIndex {
            browser.removeObserver(self, forKeyPath: "pageIndex")
            isObservingPageIndex = false
        }
    }

    // MARK: - Page Indicator

    private func addPageIndicator(to browser: PhotoBrowser, totalCount: Int, startIndex: Int) {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 22
        label.clipsToBounds = true
        label.text = "\(startIndex + 1) / \(totalCount)"
        label.translatesAutoresizingMaskIntoConstraints = false

        browser.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: browser.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            label.centerXAnchor.constraint(equalTo: browser.view.centerXAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            label.heightAnchor.constraint(equalToConstant: 44)
        ])

        pageLabel = label
    }

    // MARK: - KVO Observer

    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "pageIndex",
           let newIndex = change?[.newKey] as? Int {
            DispatchQueue.main.async {
                self.pageLabel?.text = "\(newIndex + 1) / \(self.totalAssetCount)"
            }
        }
    }
}
