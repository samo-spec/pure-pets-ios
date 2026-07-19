//
//  ModernSegmentedControlBridge.swift
//  PurePets
//
//  ObjC-compatible bridge: UIControl subclass that hosts ModernSegmentedControl
//  via UIHostingController. Drop-in replacement for PPModrenSegmrnted.
//

import SwiftUI
import UIKit

@objc(ModernSegmentedControlBridge)
@objcMembers
public class ModernSegmentedControlBridge: UIControl {

    // ── Public API (mirrors PPModrenSegmrnted) ──

    @objc public var items: [PPModrenSegmrntedItem] = [] {
        didSet { scheduleRebuild() }
    }

    @objc public var selectedIndex: Int = -1 {
        didSet {
            if selectedIndex != oldValue {
                sendActions(for: .valueChanged)
                scheduleRebuild()
                rebuildIfNeeded()
            }
        }
    }

    @objc public var containerBackgroundColor: UIColor? {
        didSet { scheduleRebuild() }
    }

    @objc public var selectedSegmentColor: UIColor? {
        didSet { scheduleRebuild() }
    }

    @objc public var normalTextColor: UIColor? {
        didSet { scheduleRebuild() }
    }

    @objc public var selectedTextColor: UIColor? {
        didSet { scheduleRebuild() }
    }

    @objc public var normalFont: UIFont? {
        didSet { scheduleRebuild() }
    }

    @objc public var selectedFont: UIFont? {
        didSet { scheduleRebuild() }
    }

    @objc public var hidesContainerChrome: Bool = false {
        didSet { scheduleRebuild() }
    }

    @objc public var numberOfSegments: Int { items.count }

    // ── Internal state ──

    private var hostingController: UIHostingController<ModernSegmentedControl>?
    private let hostingView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        return v
    }()

    private var needsRebuild = false {
        didSet {
            if needsRebuild {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.needsRebuild else { return }
                    self.needsRebuild = false
                    self.rebuild()
                }
            }
        }
    }

    // ── Init ──

    @objc public convenience init(items: [PPModrenSegmrntedItem]) {
        self.init(frame: .zero)
        self.items = items
        needsRebuild = true
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isAccessibilityElement = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // ── Rebuild ──

    private func scheduleRebuild() {
        needsRebuild = true
    }

    private func rebuildIfNeeded() {
        if needsRebuild {
            needsRebuild = false
            rebuild()
        }
    }

    private func rebuild() {
        let swiftItems = items.map {
            ModernSegmentedItem(title: $0.title,
                                iconName: $0.iconName,
                                selectedIconName: $0.selectedIconName)
        }

        let binding = Binding<Int>(
            get: { [weak self] in self?.selectedIndex ?? -1 },
            set: { [weak self] newValue in
                guard let self else { return }
                let clamped = max(-1, min(newValue, self.items.count - 1))
                if clamped != self.selectedIndex {
                    self.selectedIndex = clamped
                }
            }
        )

        let sv = ModernSegmentedControl(
            items: swiftItems,
            selectedIndex: binding,
            containerBackgroundColor: containerBackgroundColor.map { Color(uiColor: $0) },
            selectedSegmentColor: selectedSegmentColor.map { Color(uiColor: $0) },
            normalTextColor: normalTextColor.map { Color(uiColor: $0) },
            selectedTextColor: selectedTextColor.map { Color(uiColor: $0) },
            normalFont: normalFont.map { Font(uiFont: $0) },
            selectedFont: selectedFont.map { Font(uiFont: $0) },
            hidesContainerChrome: hidesContainerChrome,
            hapticsEnabled: true
        )

        if let hc = hostingController {
            hc.rootView = sv
        } else {
            let hc = UIHostingController(rootView: sv)
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            hc.view.isUserInteractionEnabled = true
            if #available(iOS 16.0, *) {
                hc.sizingOptions = .preferredContentSize
            }

            hostingView.addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.topAnchor.constraint(equalTo: hostingView.topAnchor),
                hc.view.leadingAnchor.constraint(equalTo: hostingView.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: hostingView.trailingAnchor),
                hc.view.bottomAnchor.constraint(equalTo: hostingView.bottomAnchor),
                hc.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])

            hostingController = hc
        }
    }

    // ── ObjC-compat methods ──

    @objc(setSelectedIndex:animated:)
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        let clamped = max(-1, min(index, items.count - 1))
        if clamped != selectedIndex {
            selectedIndex = clamped
        }
    }

    @objc public override var intrinsicContentSize: CGSize {
        hostingController?.view.invalidateIntrinsicContentSize()
        return hostingController?.view.intrinsicContentSize ?? CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
}

// MARK: - UIFont → Font

private extension Font {
    init(uiFont: UIFont) {
        let fd = uiFont.fontDescriptor
        let size = uiFont.pointSize
        let name = fd.postscriptName
        if fd.symbolicTraits.contains(.traitBold) {
            self = .custom(name, size: size, relativeTo: .caption).bold()
        } else {
            self = .custom(name, size: size, relativeTo: .caption)
        }
    }
}
