//
//  PPAddToCartSuccessToast.swift
//  Pure Pets
//
//  World-class top safe-area glass toast for Add to Cart success feedback.
//  Bridged to both Objective-C and SwiftUI.
//

import UIKit
import SwiftUI

// MARK: - Objective-C & Swift Entry Point

@objc(PPAddToCartSuccessToast)
public final class PPAddToCartSuccessToast: NSObject {

    /// Show top safe-area add-to-cart success toast with title and optional subtitle.
    @objc(showWithTitle:subtitle:)
    public static func show(title: String, subtitle: String?) {
        DispatchQueue.main.async {
            PPAddToCartSuccessToastPresenter.shared.show(title: title, subtitle: subtitle)
        }
    }

    /// Show top safe-area add-to-cart success toast with title.
    @objc(showWithTitle:)
    public static func show(title: String) {
        show(title: title, subtitle: nil)
    }

    /// Explicitly dismiss any presented add-to-cart success toast.
    @objc public static func dismiss() {
        DispatchQueue.main.async {
            PPAddToCartSuccessToastPresenter.shared.dismiss()
        }
    }
}

// MARK: - Toast Presenter Singleton

@MainActor
public final class PPAddToCartSuccessToastPresenter: NSObject {
    public static let shared = PPAddToCartSuccessToastPresenter()

    private var activeToastView: PPAddToCartSuccessToastView?
    private var dismissWorkItem: DispatchWorkItem?

    private override init() {
        super.init()
    }

    public func show(title: String, subtitle: String? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let cleanSubtitle = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSubtitle = (cleanSubtitle?.isEmpty ?? true) ? nil : cleanSubtitle

        // Coalesce / refresh if toast is already visible on screen
        if let existingToast = activeToastView, existingToast.superview != nil {
            dismissWorkItem?.cancel()
            existingToast.update(title: cleanTitle, subtitle: resolvedSubtitle)

            let duration: TimeInterval = resolvedSubtitle != nil ? 3.2 : 2.4
            let workItem = DispatchWorkItem { [weak self] in
                self?.dismiss()
            }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
            return
        }

        guard let keyWindow = activeKeyWindow() else { return }

        let toastView = PPAddToCartSuccessToastView(
            title: cleanTitle,
            subtitle: resolvedSubtitle,
            onDismissRequest: { [weak self] in
                self?.dismiss()
            }
        )

        activeToastView = toastView
        keyWindow.addSubview(toastView)

        // Layout constraints anchored to top safe area
        toastView.translatesAutoresizingMaskIntoConstraints = false
        let safeTop = keyWindow.safeAreaInsets.top
        let topOffset = max(safeTop + 8, 48)

        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: keyWindow.centerXAnchor),
            toastView.topAnchor.constraint(equalTo: keyWindow.topAnchor, constant: topOffset),
            toastView.widthAnchor.constraint(lessThanOrEqualTo: keyWindow.widthAnchor, constant: -32),
            toastView.widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        keyWindow.layoutIfNeeded()
        toastView.present()

        // VoiceOver Accessibility Announcement
        let announcementText: String
        if let resolvedSubtitle {
            announcementText = "\(cleanTitle), \(resolvedSubtitle)"
        } else {
            announcementText = cleanTitle
        }
        UIAccessibility.post(notification: .announcement, argument: announcementText)

        // Auto dismiss schedule
        let duration: TimeInterval = resolvedSubtitle != nil ? 3.2 : 2.4
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        self.dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    public func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        guard let toast = activeToastView else { return }
        activeToastView = nil

        toast.dismiss {
            toast.removeFromSuperview()
        }
    }

    private func activeKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
                ?? UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
}

// MARK: - UIKit Glass Toast View

public final class PPAddToCartSuccessToastView: UIView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let blurView: UIVisualEffectView
    private let stackView = UIStackView()
    private let textStack = UIStackView()

    private let onDismissRequest: () -> Void
    private var isDismissing = false

    public init(
        title: String,
        subtitle: String?,
        onDismissRequest: @escaping () -> Void
    ) {
        self.onDismissRequest = onDismissRequest

        let effect = UIBlurEffect(style: .systemThinMaterial)
        self.blurView = UIVisualEffectView(effect: effect)

        super.init(frame: .zero)

        setupView()
        update(title: title, subtitle: subtitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        layer.cornerRadius = 18.0
        layer.cornerCurve = .continuous
        clipsToBounds = true

        // Liquid Glass Border & Shadow
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 14
        layer.masksToBounds = false

        // Blur background
        blurView.layer.cornerRadius = 18.0
        blurView.layer.cornerCurve = .continuous
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        sendSubviewToBack(blurView)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        // Icon Container
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = 15.0
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.clipsToBounds = true
        iconContainer.backgroundColor = UIColor(named: "AppPrimaryColor")
            ?? UIColor(red: 0.88, green: 0.18, blue: 0.38, alpha: 1.0)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 13.0, weight: .bold)
        iconImageView.image = UIImage(systemName: "checkmark", withConfiguration: symbolConfig)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])

        // Text Labels
        titleLabel.font = UIFont(name: "Beiruti-Bold", size: 14.5)
            ?? UIFont.systemFont(ofSize: 14.5, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.85

        subtitleLabel.font = UIFont(name: "Beiruti-Regular", size: 12.5)
            ?? UIFont.systemFont(ofSize: 12.5, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.85

        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1.5
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        // Main Stack View
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10.0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(iconContainer)
        stackView.addArrangedSubview(textStack)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])

        // Gestures
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        addGestureRecognizer(swipeUp)

        isUserInteractionEnabled = true
    }

    public func update(title: String, subtitle: String?) {
        titleLabel.text = title

        if let subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }

        // Pulse content on update
        if !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.12, animations: {
                self.transform = CGAffineTransform(scaleX: 1.035, y: 1.035)
            }) { _ in
                UIView.animate(withDuration: 0.15) {
                    self.transform = .identity
                }
            }
        }
    }

    public func present() {
        if UIAccessibility.isReduceMotionEnabled {
            alpha = 0.0
            UIView.animate(withDuration: 0.18) {
                self.alpha = 1.0
            }
            return
        }

        // Initial offscreen state
        alpha = 0.0
        transform = CGAffineTransform(translationX: 0, y: -45).scaledBy(x: 0.94, y: 0.94)

        // Haptic feedback
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()

        // Spring entrance
        UIView.animate(
            withDuration: 0.52,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.alpha = 1.0
                self.transform = .identity
            },
            completion: nil
        )

        // Icon checkmark bounce
        iconContainer.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        UIView.animate(
            withDuration: 0.4,
            delay: 0.08,
            usingSpringWithDamping: 0.62,
            initialSpringVelocity: 0.8,
            options: [],
            animations: {
                self.iconContainer.transform = .identity
            },
            completion: nil
        )
    }

    public func dismiss(completion: (() -> Void)? = nil) {
        guard !isDismissing else { return }
        isDismissing = true

        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.15, animations: {
                self.alpha = 0.0
            }) { _ in
                completion?()
            }
            return
        }

        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                self.alpha = 0.0
                self.transform = CGAffineTransform(translationX: 0, y: -24).scaledBy(x: 0.96, y: 0.96)
            },
            completion: { _ in
                completion?()
            }
        )
    }

    @objc private func handleTap() {
        onDismissRequest()
    }

    @objc private func handleSwipeUp() {
        onDismissRequest()
    }
}
