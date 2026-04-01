import Foundation
import UIKit

#if canImport(HXPHPicker)
import HXPHPicker
#elseif canImport(HXPhotoPicker)
import HXPhotoPicker
#endif

#if canImport(HXPHPicker) || canImport(HXPhotoPicker)

@objc public class PPPhotoBrowserBridge: NSObject {
    private weak var observedBrowser: PhotoBrowser?
    private var isObservingPageIndex = false
    @objc public var useArabic: Bool = false
    private let core = PPCoreBridge()
    private weak var pageLabel: UILabel?
    private var totalAssetCount: Int = 0
    
    override public init() {
        super.init()
        core.useArabic = useArabic
    }
    
    // MARK: - PUBLIC ENTRY (UIImage array)
    @objc(showBrowserFrom:images:startIndex:)
    public func showBrowser(
        from vc: UIViewController,
        images: [UIImage],
        startIndex: Int
    ) {
        let assets = core.convertImagesToAssets(images)
        presentBrowser(from: vc, assets: assets, startIndex: startIndex)
    }
    
    // MARK: - PUBLIC ENTRY (URL strings)
    @objc(showBrowserFrom:imageURLStrings:startIndex:)
    public func showBrowser(
        from vc: UIViewController,
        imageURLStrings: [String],
        startIndex: Int
    ) {
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
        // Keep count for page indicator updates without relying on KVC
        self.totalAssetCount = assets.count

        // Localized language
        PhotoManager.shared
            .createLanguageBundle(languageType: useArabic ? .arabic : .english)

        // Build browser
        let browser = PhotoBrowser(
            config,
            pageIndex: startIndex,
            assets: assets
        )

        // Add page indicator (do NOT add KVO here yet)
        addPageIndicator(to: browser, totalCount: assets.count, startIndex: startIndex)

        // Present
        vc.present(browser, animated: true) { [weak self, weak browser] in
            guard let self = self, let browser = browser else { return }

            // Ensure view/layout is ready
            browser.view.setNeedsLayout()
            browser.view.layoutIfNeeded()

            // Avoid KVC for internal views (can crash if key doesn't exist).
            // Try selector-based access only if the browser exposes it.
            var internalCollectionView: UICollectionView? = nil
            let collectionViewSel = Selector(("collectionView"))
            if (browser as AnyObject).responds(to: collectionViewSel),
               let unmanaged = (browser as AnyObject).perform(collectionViewSel) {
                internalCollectionView = unmanaged.takeUnretainedValue() as? UICollectionView
            }

            // Small delay to let PhotoBrowser finish internal setup, then force reload/layout and set page
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                // 1) Force layout again
                browser.view.setNeedsLayout()
                browser.view.layoutIfNeeded()

                // 2) If collection view exists, reload & layout it, then set its offset to target page
                if let cv = internalCollectionView {
                    // reload to force cells to be created and image loading to start
                    cv.reloadData()
                    cv.layoutIfNeeded()

                    let pageWidth = cv.bounds.size.width
                    if pageWidth > 0 {
                        let targetOffset = CGPoint(x: CGFloat(startIndex) * pageWidth, y: 0)
                        cv.setContentOffset(targetOffset, animated: false)
                    } else {
                        // fallback: scroll to item
                        cv.scrollToItem(at: IndexPath(item: startIndex, section: 0), at: .centeredHorizontally, animated: false)
                    }
                }

                // 3) Try library APIs: set pageIndex, call reload/preload if available
                browser.pageIndex = startIndex
                if browser.responds(to: Selector(("setPageIndex:"))) {
                    (browser as AnyObject).setValue(startIndex, forKey: "pageIndex")
                }

                if (browser as AnyObject).responds(to: Selector(("reloadData"))) {
                    _ = (browser as AnyObject).perform(Selector(("reloadData")))
                }
                if (browser as AnyObject).responds(to: Selector(("preloadImages"))) {
                    _ = (browser as AnyObject).perform(Selector(("preloadImages")))
                }

                // 4) As an extra measure, try calling a 'visibleCells' update if present
                if (browser as AnyObject).responds(to: Selector(("updateVisibleCells"))) {
                    _ = (browser as AnyObject).perform(Selector(("updateVisibleCells")))
                }

                // 5) Add KVO observer (existing logic)
                if let previous = self.observedBrowser, self.isObservingPageIndex {
                    previous.removeObserver(self, forKeyPath: "pageIndex")
                    self.isObservingPageIndex = false
                }
                self.observedBrowser = browser
                browser.addObserver(self,
                                    forKeyPath: "pageIndex",
                                    options: [.new],
                                    context: nil)
                self.isObservingPageIndex = true
            }
        }
        
        @discardableResult
        func objcPerform(_ target: AnyObject, selector: Selector, with arg: Any? = nil) -> Unmanaged<AnyObject>? {
            if target.responds(to: selector) {
                if let a = arg {
                    return target.perform(selector, with: a)
                } else {
                    return target.perform(selector)
                }
            }
            return nil
        }

        // usage
        _ = objcPerform(browser as AnyObject, selector: Selector(("preloadImages")))
        
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
    
    // MARK: - Add Page Indicator
    // MARK: - Add Page Indicator
    private func addPageIndicator(to browser: PhotoBrowser, totalCount: Int, startIndex: Int) {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 22
        label.clipsToBounds = true

        // Set initial text
        label.text = "\(startIndex + 1) / \(totalCount)"

        // Size and position
        label.translatesAutoresizingMaskIntoConstraints = false
        browser.view.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: browser.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            label.centerXAnchor.constraint(equalTo: browser.view.centerXAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            label.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Store reference
        self.pageLabel = label

        // NOTE: we DO NOT add the observer here anymore.
        // The observer is added after presentation to avoid receiving pageIndex changes
        // before the browser has laid out its content.
    }
    
    // MARK: - KVO Observer
    public override func observeValue(forKeyPath keyPath: String?,
                                    of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?,
                                    context: UnsafeMutableRawPointer?) {
        
        if keyPath == "pageIndex",
           let browser = object as? PhotoBrowser,
           let newIndex = change?[.newKey] as? Int {
            DispatchQueue.main.async {
                self.pageLabel?.text = "\(newIndex + 1) / \(self.totalAssetCount)"
            }
        }
    }
}

#else

@objc public class PPPhotoBrowserBridge: NSObject {
    @objc public var useArabic: Bool = false

    @objc(showBrowserFrom:images:startIndex:)
    public func showBrowser(
        from vc: UIViewController,
        images: [UIImage],
        startIndex: Int
    ) {
        _ = vc
        _ = images
        _ = startIndex
    }

    @objc(showBrowserFrom:imageURLStrings:startIndex:)
    public func showBrowser(
        from vc: UIViewController,
        imageURLStrings: [String],
        startIndex: Int
    ) {
        _ = vc
        _ = imageURLStrings
        _ = startIndex
    }
}

#endif
