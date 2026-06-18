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
    private let ambientGlowView = UIView()
    private let secondaryGlowView = UIView()
    private let accentView = UIView()
    private let avatarView = UIView()
    private let novaLeadingView = PPNovaAmbientAssistantChatBridge.makeAmbientLeadingView()
    private let messageLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let liquidBorderView = UIView()
    private let liquidBorderLayer = CAShapeLayer()
    private let borderHighlightLayer = CAShapeLayer()
    private let avatarHaloLayer = CAShapeLayer()
    private let accentGlowLayer = CAShapeLayer()

    private var closeHandler: (() -> Void)?
    private let microMotionKey = "pp.novaAmbient.microMotion"
    private let attentionMotionKey = "pp.novaAmbient.attentionMotion"
    private let borderHighlightMotionKey = "pp.novaAmbient.borderHighlightFlow"
    private let glowBreathMotionKey = "pp.novaAmbient.glowBreath"
    private let avatarBreathMotionKey = "pp.novaAmbient.avatarBreath"
    private let accentBreathMotionKey = "pp.novaAmbient.accentBreath"
    private let fallbackCapsuleHeight: CGFloat = 60.0
    private var normalShadowOpacity: Float {
        traitCollection.userInterfaceStyle == .dark ? 0.42 : 0.34
    }
    private var pressedShadowOpacity: Float {
        traitCollection.userInterfaceStyle == .dark ? 0.26 : 0.22
    }

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

    public override func layoutSubviews() {
        super.layoutSubviews()
        refreshLiquidGeometry()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopAmbientMotion()
        } else if alpha > 0.98 {
            startMicroMotionIfNeeded()
        }
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
        transform = CGAffineTransform(translationX: 0.0, y: 18.0).scaledBy(x: 0.94, y: 0.94)
        blurView.contentView.alpha = 0.0
        ambientGlowView.alpha = 0.0
        secondaryGlowView.alpha = 0.0
        accentView.alpha = 0.0
        accentView.transform = CGAffineTransform(scaleX: 1.0, y: 0.28)
        avatarView.alpha = 0.0
        avatarView.transform = CGAffineTransform(scaleX: 0.84, y: 0.84)
        messageLabel.alpha = 0.0
        messageLabel.transform = CGAffineTransform(translationX: 0.0, y: 7.0)
        closeButton.alpha = 0.0
        closeButton.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        liquidBorderView.alpha = 0.0
        stopAmbientMotion()
    }

    public func animateIn() {
        layer.removeAllAnimations()
        if UIAccessibility.isReduceMotionEnabled {
            transform = .identity
            accentView.transform = .identity
            avatarView.transform = .identity
            messageLabel.transform = .identity
            closeButton.transform = .identity
            UIView.animate(withDuration: 0.18, delay: 0.0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.alpha = 1.0
                self.blurView.contentView.alpha = 1.0
                self.ambientGlowView.alpha = 1.0
                self.secondaryGlowView.alpha = 1.0
                self.accentView.alpha = 1.0
                self.avatarView.alpha = 1.0
                self.messageLabel.alpha = 1.0
                self.closeButton.alpha = 1.0
                self.liquidBorderView.alpha = 1.0
            } completion: { _ in
                self.startMicroMotionIfNeeded()
            }
            return
        }

        UIView.animate(
            withDuration: 0.54,
            delay: 0.0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.36,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            self.alpha = 1.0
            self.transform = .identity
            self.layer.shadowOpacity = self.normalShadowOpacity
        } completion: { _ in
            self.startMicroMotionIfNeeded()
        }

        UIView.animate(
            withDuration: 0.34,
            delay: 0.06,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            self.blurView.contentView.alpha = 1.0
            self.ambientGlowView.alpha = 1.0
            self.secondaryGlowView.alpha = 1.0
            self.liquidBorderView.alpha = 1.0
        }

        UIView.animate(
            withDuration: 0.40,
            delay: 0.10,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.24,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.accentView.alpha = 1.0
            self.accentView.transform = .identity
            self.avatarView.alpha = 1.0
            self.avatarView.transform = .identity
        }

        UIView.animate(
            withDuration: 0.30,
            delay: 0.16,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]
        ) {
            self.messageLabel.alpha = 1.0
            self.messageLabel.transform = .identity
        }

        UIView.animate(
            withDuration: 0.24,
            delay: 0.22,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.18,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.closeButton.alpha = 1.0
            self.closeButton.transform = .identity
        }
    }

    public func animateOut(completion: (() -> Void)? = nil) {
        stopAmbientMotion()
        let animations = {
            self.alpha = 0.0
            self.blurView.contentView.alpha = 0.0
            self.liquidBorderView.alpha = 0.0
            self.transform = UIAccessibility.isReduceMotionEnabled
                ? .identity
                : CGAffineTransform(translationX: 0.0, y: 12.0).scaledBy(x: 0.965, y: 0.965)
        }

        UIView.animate(
            withDuration: UIAccessibility.isReduceMotionEnabled ? 0.14 : 0.24,
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

        let borderPulse = CAKeyframeAnimation(keyPath: "opacity")
        borderPulse.values = [
            NSNumber(value: liquidBorderLayer.opacity),
            NSNumber(value: 1.0),
            NSNumber(value: 0.74)
        ]
        borderPulse.keyTimes = [
            NSNumber(value: 0.0),
            NSNumber(value: 0.34),
            NSNumber(value: 1.0)
        ]
        borderPulse.duration = 0.42
        borderPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        liquidBorderLayer.add(borderPulse, forKey: attentionMotionKey)
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

        ambientGlowView.translatesAutoresizingMaskIntoConstraints = false
        ambientGlowView.isUserInteractionEnabled = false
        blurView.contentView.addSubview(ambientGlowView)

        secondaryGlowView.translatesAutoresizingMaskIntoConstraints = false
        secondaryGlowView.isUserInteractionEnabled = false
        blurView.contentView.addSubview(secondaryGlowView)

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

        liquidBorderView.translatesAutoresizingMaskIntoConstraints = false
        liquidBorderView.isUserInteractionEnabled = false
        liquidBorderView.backgroundColor = .clear
        addSubview(liquidBorderView)

        NSLayoutConstraint.activate([
            glassBackgroundButton.topAnchor.constraint(equalTo: topAnchor),
            glassBackgroundButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackgroundButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassBackgroundButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            ambientGlowView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: -24.0),
            ambientGlowView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: -28.0),
            ambientGlowView.widthAnchor.constraint(equalToConstant: 96.0),
            ambientGlowView.heightAnchor.constraint(equalToConstant: 82.0),

            secondaryGlowView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: 20.0),
            secondaryGlowView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: 22.0),
            secondaryGlowView.widthAnchor.constraint(equalToConstant: 76.0),
            secondaryGlowView.heightAnchor.constraint(equalToConstant: 64.0),

            accentView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 11.0),
            accentView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            accentView.widthAnchor.constraint(equalToConstant: 3.5),
            accentView.heightAnchor.constraint(equalToConstant: 32.0),

            avatarView.leadingAnchor.constraint(equalTo: accentView.trailingAnchor, constant: 11.0),
            avatarView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 40.0),
            avatarView.heightAnchor.constraint(equalToConstant: 40.0),

            novaLeadingView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            novaLeadingView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            novaLeadingView.widthAnchor.constraint(equalToConstant: 36.0),
            novaLeadingView.heightAnchor.constraint(equalToConstant: 36.0),

            messageLabel.topAnchor.constraint(greaterThanOrEqualTo: blurView.contentView.topAnchor, constant: 12.0),
            messageLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10.0),
            messageLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4.0),
            messageLabel.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: blurView.contentView.bottomAnchor, constant: -12.0),

            closeButton.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -6.0),
            closeButton.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44.0),
            closeButton.heightAnchor.constraint(equalToConstant: 44.0),

            liquidBorderView.topAnchor.constraint(equalTo: topAnchor),
            liquidBorderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            liquidBorderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            liquidBorderView.bottomAnchor.constraint(equalTo: bottomAnchor),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 60.0)
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
        layer.shadowOpacity = normalShadowOpacity
        layer.shadowRadius = 28.0
        layer.shadowOffset = CGSize(width: 0.0, height: 16.0)

        applyCapsuleCornerRadius(fallbackCapsuleHeight * 0.5)
        if #available(iOS 13.0, *) {
            glassBackgroundButton.layer.cornerCurve = .continuous
        }

        if #available(iOS 13.0, *) {
            blurView.layer.cornerCurve = .continuous
        }

        ambientGlowView.layer.cornerRadius = 41.0
        secondaryGlowView.layer.cornerRadius = 32.0

        avatarView.layer.cornerRadius = 20.0
        if #available(iOS 13.0, *) {
            avatarView.layer.cornerCurve = .continuous
        }

        accentView.layer.cornerRadius = 1.75
        closeButton.layer.cornerRadius = 22.0
        if #available(iOS 13.0, *) {
            closeButton.layer.cornerCurve = .continuous
        }

        liquidBorderView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            liquidBorderView.layer.cornerCurve = .continuous
        }
        liquidBorderView.layer.addSublayer(liquidBorderLayer)
        liquidBorderView.layer.addSublayer(borderHighlightLayer)
        liquidBorderLayer.fillColor = UIColor.clear.cgColor
        liquidBorderLayer.lineCap = .round
        liquidBorderLayer.lineJoin = .round
        borderHighlightLayer.fillColor = UIColor.clear.cgColor
        borderHighlightLayer.lineCap = .round
        borderHighlightLayer.lineJoin = .round

        avatarView.layer.insertSublayer(avatarHaloLayer, at: 0)
        accentView.layer.insertSublayer(accentGlowLayer, at: 0)
        avatarHaloLayer.fillColor = UIColor.clear.cgColor
        accentGlowLayer.fillColor = UIColor.clear.cgColor
        accentGlowLayer.lineCap = .round

        let closeConfig = UIImage.SymbolConfiguration(pointSize: 11.0, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)

        messageLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
            for: UIFont(name: "Beiruti-Bold", size: 15.0) ?? UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        )
    }

    private func applyDynamicStyle() {
        let accent = UIColor(named: "AppPrimaryColor") ?? UIColor.systemOrange
        let isDark = traitCollection.userInterfaceStyle == .dark
        let softCyan = UIColor(red: 0.38, green: 0.90, blue: 1.0, alpha: 1.0)
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled

        layer.shadowOpacity = normalShadowOpacity
        layer.shadowColor = (isDark ? UIColor.black : accent.withAlphaComponent(0.38)).cgColor

        if #available(iOS 26.0, *) {
            glassBackgroundButton.isHidden = reduceTransparency
            glassBackgroundButton.backgroundColor = .clear
            blurView.effect = reduceTransparency ? nil : UIBlurEffect(style: .systemUltraThinMaterial)
            blurView.backgroundColor = reduceTransparency
                ? (isDark ? UIColor(white: 0.08, alpha: 0.96) : UIColor(white: 1.0, alpha: 0.96))
                : UIColor.clear
            blurView.layer.borderWidth = 0.0
            blurView.layer.borderColor = UIColor.clear.cgColor
        } else {
            glassBackgroundButton.isHidden = true
            blurView.effect = reduceTransparency ? nil : UIBlurEffect(style: .systemUltraThinMaterial)
            blurView.backgroundColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 0.07, alpha: reduceTransparency ? 0.96 : 0.62)
                    : UIColor(white: 1.0, alpha: reduceTransparency ? 0.96 : 0.70)
            }
            blurView.layer.borderWidth = 1.0 / UIScreen.main.scale
            blurView.layer.borderColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.12)
                    : UIColor(white: 0.0, alpha: 0.08)
            }.cgColor
        }

        ambientGlowView.backgroundColor = accent.withAlphaComponent(isDark ? 0.22 : 0.16)
        secondaryGlowView.backgroundColor = softCyan.withAlphaComponent(isDark ? 0.14 : 0.10)
        ambientGlowView.layer.shadowColor = accent.cgColor
        ambientGlowView.layer.shadowOpacity = isDark ? 0.32 : 0.22
        ambientGlowView.layer.shadowRadius = 18.0
        ambientGlowView.layer.shadowOffset = .zero
        secondaryGlowView.layer.shadowColor = softCyan.cgColor
        secondaryGlowView.layer.shadowOpacity = isDark ? 0.18 : 0.12
        secondaryGlowView.layer.shadowRadius = 16.0
        secondaryGlowView.layer.shadowOffset = .zero

        accentView.backgroundColor = accent.withAlphaComponent(isDark ? 0.92 : 0.96)
        avatarView.backgroundColor = accent.withAlphaComponent(isDark ? 0.20 : 0.13)
        avatarView.layer.borderWidth = 1.0 / UIScreen.main.scale
        avatarView.layer.borderColor = accent.withAlphaComponent(isDark ? 0.34 : 0.24).cgColor
        messageLabel.textColor = .label
        closeButton.tintColor = .secondaryLabel
        closeButton.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.06)
                : UIColor(white: 0.0, alpha: 0.04)
        }

        liquidBorderLayer.strokeColor = UIColor.white.withAlphaComponent(isDark ? 0.68 : 0.82).cgColor
        liquidBorderLayer.shadowColor = UIColor.white.cgColor
        liquidBorderLayer.shadowOpacity = isDark ? 0.16 : 0.20
        liquidBorderLayer.shadowRadius = 2.0
        liquidBorderLayer.shadowOffset = .zero
        borderHighlightLayer.strokeColor = UIColor.white.withAlphaComponent(isDark ? 0.92 : 1.0).cgColor
        borderHighlightLayer.shadowColor = UIColor.white.cgColor
        borderHighlightLayer.shadowOpacity = isDark ? 0.22 : 0.26
        borderHighlightLayer.shadowRadius = 2.0
        borderHighlightLayer.shadowOffset = .zero
        avatarHaloLayer.strokeColor = accent.withAlphaComponent(isDark ? 0.46 : 0.30).cgColor
        accentGlowLayer.strokeColor = accent.withAlphaComponent(isDark ? 0.62 : 0.44).cgColor
        accentGlowLayer.shadowColor = accent.cgColor
        accentGlowLayer.shadowOpacity = isDark ? 0.50 : 0.34
        accentGlowLayer.shadowRadius = 8.0
        accentGlowLayer.shadowOffset = .zero
        refreshLiquidGeometry()
    }

    private func updatePressedState(animated: Bool) {
        let transform = isHighlighted && !UIAccessibility.isReduceMotionEnabled
            ? CGAffineTransform(scaleX: 0.982, y: 0.982)
            : .identity
        let changes = {
            self.transform = transform
            self.layer.shadowOpacity = self.isHighlighted ? self.pressedShadowOpacity : self.normalShadowOpacity
            self.liquidBorderView.alpha = self.isHighlighted ? 0.84 : 1.0
            self.ambientGlowView.alpha = self.isHighlighted ? 0.82 : 1.0
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
        motion.fromValue = -1.2
        motion.toValue = 1.2
        motion.duration = 4.2
        motion.autoreverses = true
        motion.repeatCount = .greatestFiniteMagnitude
        motion.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(motion, forKey: microMotionKey)
        startLiquidMotionIfNeeded()
    }

    private func stopAmbientMotion() {
        layer.removeAnimation(forKey: microMotionKey)
        borderHighlightLayer.removeAnimation(forKey: borderHighlightMotionKey)
        ambientGlowView.layer.removeAnimation(forKey: glowBreathMotionKey)
        secondaryGlowView.layer.removeAnimation(forKey: glowBreathMotionKey)
        avatarHaloLayer.removeAnimation(forKey: avatarBreathMotionKey)
        accentGlowLayer.removeAnimation(forKey: accentBreathMotionKey)
    }

    private func startLiquidMotionIfNeeded() {
        guard window != nil, !UIAccessibility.isReduceMotionEnabled else { return }
        borderHighlightLayer.removeAnimation(forKey: borderHighlightMotionKey)
        ambientGlowView.layer.removeAnimation(forKey: glowBreathMotionKey)
        secondaryGlowView.layer.removeAnimation(forKey: glowBreathMotionKey)
        avatarHaloLayer.removeAnimation(forKey: avatarBreathMotionKey)
        accentGlowLayer.removeAnimation(forKey: accentBreathMotionKey)

        let phaseDistance = max(360.0, (bounds.width + bounds.height) * 2.0)
        let highlightFlow = CABasicAnimation(keyPath: "lineDashPhase")
        highlightFlow.fromValue = 0.0
        highlightFlow.toValue = -phaseDistance
        highlightFlow.duration = 3.4
        highlightFlow.repeatCount = .greatestFiniteMagnitude
        highlightFlow.timingFunction = CAMediaTimingFunction(name: .linear)
        borderHighlightLayer.add(highlightFlow, forKey: borderHighlightMotionKey)

        let glowBreath = CABasicAnimation(keyPath: "transform.scale")
        glowBreath.fromValue = 0.985
        glowBreath.toValue = 1.025
        glowBreath.duration = 4.4
        glowBreath.autoreverses = true
        glowBreath.repeatCount = .greatestFiniteMagnitude
        glowBreath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ambientGlowView.layer.add(glowBreath, forKey: glowBreathMotionKey)

        let secondaryBreath = CABasicAnimation(keyPath: "opacity")
        secondaryBreath.fromValue = 0.72
        secondaryBreath.toValue = 1.0
        secondaryBreath.duration = 5.2
        secondaryBreath.autoreverses = true
        secondaryBreath.repeatCount = .greatestFiniteMagnitude
        secondaryBreath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        secondaryGlowView.layer.add(secondaryBreath, forKey: glowBreathMotionKey)

        let avatarBreath = CABasicAnimation(keyPath: "opacity")
        avatarBreath.fromValue = 0.38
        avatarBreath.toValue = 0.74
        avatarBreath.duration = 3.6
        avatarBreath.autoreverses = true
        avatarBreath.repeatCount = .greatestFiniteMagnitude
        avatarBreath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        avatarHaloLayer.add(avatarBreath, forKey: avatarBreathMotionKey)

        let accentBreath = CABasicAnimation(keyPath: "opacity")
        accentBreath.fromValue = 0.44
        accentBreath.toValue = 0.82
        accentBreath.duration = 3.2
        accentBreath.autoreverses = true
        accentBreath.repeatCount = .greatestFiniteMagnitude
        accentBreath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        accentGlowLayer.add(accentBreath, forKey: accentBreathMotionKey)
    }

    private func refreshLiquidGeometry() {
        guard bounds.width > 0.0, bounds.height > 0.0 else { return }

        let cornerRadius = bounds.height * 0.5
        let borderInset: CGFloat = 1.0
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        applyCapsuleCornerRadius(cornerRadius)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath

        let borderBounds = liquidBorderView.bounds
        let borderPath = UIBezierPath(
            roundedRect: borderBounds.insetBy(dx: borderInset, dy: borderInset),
            cornerRadius: max(0.0, cornerRadius - borderInset)
        ).cgPath

        liquidBorderLayer.frame = borderBounds
        liquidBorderLayer.path = borderPath
        liquidBorderLayer.lineWidth = 1.0
        liquidBorderLayer.opacity = 0.78

        let borderPerimeter = max(360.0, (borderBounds.width + borderBounds.height) * 2.0)
        borderHighlightLayer.frame = borderBounds
        borderHighlightLayer.path = borderPath
        borderHighlightLayer.lineWidth = 1.2
        borderHighlightLayer.lineDashPattern = [
            NSNumber(value: 34.0),
            NSNumber(value: Double(max(170.0, borderPerimeter - 34.0)))
        ]
        borderHighlightLayer.opacity = 0.86

        avatarHaloLayer.frame = avatarView.bounds
        avatarHaloLayer.path = UIBezierPath(
            ovalIn: avatarView.bounds.insetBy(dx: 2.0, dy: 2.0)
        ).cgPath
        avatarHaloLayer.lineWidth = 1.0
        avatarHaloLayer.opacity = 0.54

        accentGlowLayer.frame = accentView.bounds
        let accentPath = UIBezierPath()
        accentPath.move(to: CGPoint(x: accentView.bounds.midX, y: 3.0))
        accentPath.addLine(to: CGPoint(x: accentView.bounds.midX, y: max(3.0, accentView.bounds.height - 3.0)))
        accentGlowLayer.path = accentPath.cgPath
        accentGlowLayer.lineWidth = max(2.0, accentView.bounds.width)
        accentGlowLayer.opacity = 0.64

        CATransaction.commit()
    }

    private func applyCapsuleCornerRadius(_ radius: CGFloat) {
        glassBackgroundButton.layer.cornerRadius = radius
        blurView.layer.cornerRadius = radius
        liquidBorderView.layer.cornerRadius = radius
        liquidBorderView.layer.masksToBounds = true
    }

    @objc private func closeTapped() {
        closeHandler?()
    }
}
