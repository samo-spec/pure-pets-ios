//
//  NovaAmbientAssistantView.swift
//  Pure Pets
//
//  A compact, contextual Nova surface. This is presentation-only and does not
//  change Nova chat, backend, Firebase, or API behavior.
//

import UIKit

@objc(NovaAmbientAssistantView)
public final class NovaAmbientAssistantView: UIControl {
    private let blurView: UIVisualEffectView
    private let glassBackgroundButton = PPNovaAmbientAssistantChatBridge.makeAmbientGlassBackgroundButton()
    private let accentView = UIView()
    private let avatarView = UIView()
    private let novaLeadingView = PPNovaAmbientAssistantChatBridge.makeAmbientLeadingView()
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private var closeHandler: (() -> Void)?
    private let microMotionKey = "pp.novaAmbient.microMotion"
    private let attentionMotionKey = "pp.novaAmbient.attentionMotion"

    public override init(frame: CGRect) {
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        super.init(frame: frame)
        buildHierarchy()
        applyStaticStyle()
        applyDynamicStyle()
        prepareForEntrance()
    }

    required init?(coder: NSCoder) {
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        super.init(coder: coder)
        buildHierarchy()
        applyStaticStyle()
        applyDynamicStyle()
        prepareForEntrance()
    }

    public override var isHighlighted: Bool {
        didSet { updatePressedState(animated: true) }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyDynamicStyle()
    }

    @objc(configureWithMessage:)
    public func configure(message: String) {
        messageLabel.text = message
        accessibilityLabel = message
        accessibilityHint = NSLocalizedString("nova_ambient_accessibility_hint", comment: "")
    }

    public func setCloseHandler(_ handler: @escaping () -> Void) {
        closeHandler = handler
    }

    public func prepareForEntrance() {
        alpha = 0.0
        transform = CGAffineTransform(translationX: 0.0, y: 10.0).scaledBy(x: 0.96, y: 0.96)
        stopMicroMotion()
    }

    public func animateIn() {
        layer.removeAllAnimations()
        if UIAccessibility.isReduceMotionEnabled {
            transform = .identity
            UIView.animate(withDuration: 0.18, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.alpha = 1.0
            } completion: { _ in
                self.startMicroMotionIfNeeded()
            }
            return
        }

        UIView.animate(
            withDuration: 0.46,
            delay: 0.0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.42,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.alpha = 1.0
            self.transform = .identity
        } completion: { _ in
            self.startMicroMotionIfNeeded()
        }
    }

    public func animateOut(completion: (() -> Void)? = nil) {
        stopMicroMotion()
        let animations = {
            self.alpha = 0.0
            self.transform = UIAccessibility.isReduceMotionEnabled
                ? .identity
                : CGAffineTransform(translationX: 0.0, y: 8.0).scaledBy(x: 0.97, y: 0.97)
        }

        UIView.animate(
            withDuration: UIAccessibility.isReduceMotionEnabled ? 0.14 : 0.22,
            delay: 0.0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
            animations: animations,
            completion: { _ in completion?() }
        )
    }

    public func animateAttention() {
        alpha = 1.0
        layer.removeAnimation(forKey: attentionMotionKey)
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0.0, -5.0, 4.0, -2.5, 1.5, 0.0]
        animation.duration = 0.34
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: attentionMotionKey)
    }

    private func buildHierarchy() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        semanticContentAttribute = .unspecified

        glassBackgroundButton.translatesAutoresizingMaskIntoConstraints = false
        glassBackgroundButton.isUserInteractionEnabled = false
        glassBackgroundButton.backgroundColor = .clear
        addSubview(glassBackgroundButton)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true
        blurView.backgroundColor = .clear
        addSubview(blurView)

        accentView.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(accentView)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.isUserInteractionEnabled = false
        blurView.contentView.addSubview(avatarView)

        novaLeadingView.translatesAutoresizingMaskIntoConstraints = false
        novaLeadingView.isAccessibilityElement = false
        avatarView.addSubview(novaLeadingView)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byTruncatingTail
        blurView.contentView.addSubview(messageLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.accessibilityLabel = NSLocalizedString("nova_ambient_close_accessibility", comment: "")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        blurView.contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            glassBackgroundButton.topAnchor.constraint(equalTo: topAnchor),
            glassBackgroundButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackgroundButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackgroundButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            accentView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 10.0),
            accentView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            accentView.widthAnchor.constraint(equalToConstant: 3.0),
            accentView.heightAnchor.constraint(equalToConstant: 30.0),

            avatarView.leadingAnchor.constraint(equalTo: accentView.trailingAnchor, constant: 10.0),
            avatarView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 42.0),
            avatarView.heightAnchor.constraint(equalToConstant: 42.0),

            novaLeadingView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            novaLeadingView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            novaLeadingView.widthAnchor.constraint(equalToConstant: 38.0),
            novaLeadingView.heightAnchor.constraint(equalToConstant: 38.0),

            messageLabel.topAnchor.constraint(greaterThanOrEqualTo: blurView.contentView.topAnchor, constant: 12.0),
            messageLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10.0),
            messageLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4.0),
            messageLabel.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -12.0),

            closeButton.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -6.0),
            closeButton.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44.0),
            closeButton.heightAnchor.constraint(equalToConstant: 44.0),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 64.0)
        ])

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(closeTapped))
        swipeDown.direction = .down
        addGestureRecognizer(swipeDown)

        let swipeLeading = UISwipeGestureRecognizer(target: self, action: #selector(closeTapped))
        swipeLeading.direction = [.left, .right]
        addGestureRecognizer(swipeLeading)
    }

    private func applyStaticStyle() {
        clipsToBounds = false
        layer.shadowOpacity = 0.16
        layer.shadowRadius = 24.0
        layer.shadowOffset = CGSize(width: 0.0, height: 10.0)

        glassBackgroundButton.layer.cornerRadius = 25.0
        if #available(iOS 13.0, *) {
            glassBackgroundButton.layer.cornerCurve = .continuous
        }

        blurView.layer.cornerRadius = 25.0
        if #available(iOS 13.0, *) {
            blurView.layer.cornerCurve = .continuous
        }

        avatarView.layer.cornerRadius = 21.0
        if #available(iOS 13.0, *) {
            avatarView.layer.cornerCurve = .continuous
        }

        accentView.layer.cornerRadius = 1.5
        closeButton.layer.cornerRadius = 18.0
        if #available(iOS 13.0, *) {
            closeButton.layer.cornerCurve = .continuous
        }

        let closeConfig = UIImage.SymbolConfiguration(pointSize: 11.0, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)

        messageLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: UIFont(name: "Beiruti-Bold", size: 15.0) ?? UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        )
    }

    private func applyDynamicStyle() {
        let accent = UIColor(named: "AppPrimaryColor") ?? UIColor.systemOrange
        let isDark = traitCollection.userInterfaceStyle == .dark

        layer.shadowColor = (isDark ? UIColor.black : UIColor(white: 0.10, alpha: 1.0)).cgColor

        if #available(iOS 26.0, *) {
            glassBackgroundButton.isHidden = false
            glassBackgroundButton.backgroundColor = .clear
            blurView.effect = nil
            blurView.backgroundColor = .clear
            blurView.layer.borderWidth = 0.0
            blurView.layer.borderColor = UIColor.clear.cgColor
        } else {
            glassBackgroundButton.isHidden = true
            blurView.effect = UIBlurEffect(style: .systemUltraThinMaterial)
            blurView.backgroundColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.07, alpha: 0.58)
                    : UIColor(white: 1.0, alpha: 0.66)
            }
            blurView.layer.borderWidth = 1.0 / UIScreen.main.scale
            blurView.layer.borderColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.12)
                    : UIColor(white: 0.0, alpha: 0.08)
            }.cgColor
        }

        accentView.backgroundColor = accent.withAlphaComponent(isDark ? 0.82 : 0.92)
        avatarView.backgroundColor = accent.withAlphaComponent(isDark ? 0.18 : 0.12)
        avatarView.layer.borderWidth = 1.0 / UIScreen.main.scale
        avatarView.layer.borderColor = accent.withAlphaComponent(isDark ? 0.28 : 0.20).cgColor
        messageLabel.textColor = .label
        closeButton.tintColor = .secondaryLabel
        closeButton.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.06)
                : UIColor(white: 0.0, alpha: 0.04)
        }
    }

    private func updatePressedState(animated: Bool) {
        let transform = isHighlighted && !UIAccessibility.isReduceMotionEnabled
            ? CGAffineTransform(scaleX: 0.985, y: 0.985)
            : .identity
        let changes = {
            self.transform = transform
            self.layer.shadowOpacity = self.isHighlighted ? 0.10 : 0.16
        }
        guard animated else {
            changes()
            return
        }
        UIView.animate(
            withDuration: isHighlighted ? 0.10 : 0.18,
            delay: 0.0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
            animations: changes
        )
    }

    private func startMicroMotionIfNeeded() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        layer.removeAnimation(forKey: microMotionKey)
        let motion = CABasicAnimation(keyPath: "transform.translation.y")
        motion.fromValue = -1.5
        motion.toValue = 1.5
        motion.duration = 3.8
        motion.autoreverses = true
        motion.repeatCount = .greatestFiniteMagnitude
        motion.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(motion, forKey: microMotionKey)
    }

    private func stopMicroMotion() {
        layer.removeAnimation(forKey: microMotionKey)
    }

    @objc private func closeTapped() {
        closeHandler?()
    }
}
