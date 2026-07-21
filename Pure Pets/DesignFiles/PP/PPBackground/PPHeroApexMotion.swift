//
//  PPHeroApexMotion.swift
//  Pure Pets
//
//  Deterministic motion policy and semantic timing for PPHeroApex.
//

import UIKit

enum PPHeroApexMotionState: Equatable {
    case detached
    case idle
    case suspended
    case reduced
    case entering
    case ambient
    case interactive
    case settling
}

struct PPHeroApexMotionEnvironment: Equatable {
    var isAttached: Bool
    var hasValidGeometry: Bool
    var isApplicationActive: Bool
    var isReduceMotionEnabled: Bool
    var isLowPowerModeEnabled: Bool
    var isThermallyConstrained: Bool

    static let detached = PPHeroApexMotionEnvironment(
        isAttached: false,
        hasValidGeometry: false,
        isApplicationActive: false,
        isReduceMotionEnabled: false,
        isLowPowerModeEnabled: false,
        isThermallyConstrained: false
    )

    var requiresStaticPresentation: Bool {
        isReduceMotionEnabled || isLowPowerModeEnabled || isThermallyConstrained
    }
}

enum PPHeroApexMotionEvent: Equatable {
    case environmentChanged(PPHeroApexMotionEnvironment)
    case startRequested
    case stopRequested
    case entranceCompleted(generation: UInt)
    case interactionBegan
    case interactionEnded
    case settlingCompleted(generation: UInt)
}

struct PPHeroApexMotionTransition: Equatable {
    let previous: PPHeroApexMotionState
    let current: PPHeroApexMotionState
    let generation: UInt
}

struct PPHeroApexMotionStateMachine {
    private(set) var state: PPHeroApexMotionState = .detached
    private(set) var generation: UInt = 0
    private(set) var wantsMotion = true
    private(set) var hasCompletedEntrance = false
    private(set) var environment = PPHeroApexMotionEnvironment.detached

    mutating func send(_ event: PPHeroApexMotionEvent) -> PPHeroApexMotionTransition? {
        let previous = state

        switch event {
        case .environmentChanged(let newEnvironment):
            environment = newEnvironment
            let unconstrainedState = resolvedBaseState(preservingInteraction: false)
            if state == .entering && unconstrainedState != .entering {
                hasCompletedEntrance = true
            }
            if unconstrainedState == .reduced {
                hasCompletedEntrance = true
            }
            state = resolvedBaseState(preservingInteraction: true)

        case .startRequested:
            wantsMotion = true
            let resolvedState = resolvedBaseState(preservingInteraction: true)
            if resolvedState == .reduced {
                hasCompletedEntrance = true
            }
            state = resolvedBaseState(preservingInteraction: true)

        case .stopRequested:
            wantsMotion = false
            if state == .entering {
                hasCompletedEntrance = true
            }
            state = environment.isAttached ? .idle : .detached

        case .entranceCompleted(let completionGeneration):
            guard state == .entering,
                  completionGeneration == generation else {
                return nil
            }
            hasCompletedEntrance = true
            state = resolvedBaseState(preservingInteraction: false)

        case .interactionBegan:
            guard state == .ambient || state == .settling else {
                return nil
            }
            state = .interactive

        case .interactionEnded:
            guard state == .interactive else {
                return nil
            }
            state = .settling

        case .settlingCompleted(let completionGeneration):
            guard state == .settling,
                  completionGeneration == generation else {
                return nil
            }
            state = resolvedBaseState(preservingInteraction: false)
        }

        guard state != previous else { return nil }
        generation &+= 1
        return PPHeroApexMotionTransition(
            previous: previous,
            current: state,
            generation: generation
        )
    }

    private func resolvedBaseState(preservingInteraction: Bool) -> PPHeroApexMotionState {
        guard environment.isAttached else { return .detached }
        guard wantsMotion else { return .idle }
        guard environment.hasValidGeometry,
              environment.isApplicationActive else {
            return .suspended
        }
        guard !environment.requiresStaticPresentation else { return .reduced }

        if preservingInteraction && (state == .interactive || state == .settling) {
            return state
        }
        return hasCompletedEntrance ? .ambient : .entering
    }
}

enum PPHeroApexMotionTokens {
    // Entrance is deliberately slower than a control highlight but faster than
    // a navigation transition. It should register as material resolving into
    // focus, never as a card flying onto the screen.
    static let entranceDuration: TimeInterval = 0.42
    static let overlayEntranceDuration: TimeInterval = 0.32
    static let overlayEntranceDelay: TimeInterval = 0.07

    // Optical state changes use one family of curves, so accent, palette and
    // interaction updates feel authored by the same motion system.
    static let accentTransitionDuration: CFTimeInterval = 0.28
    static let paletteTransitionDuration: CFTimeInterval = 0.54
    static let interactionSettleDuration: TimeInterval = 0.44
    static let tapPulseDuration: CFTimeInterval = 0.58
    static let contactWaveDuration: CFTimeInterval = 0.72

    // Ambient cycles are intentionally long. The hero should feel alive when
    // revisited, not visibly loop while the user is reading it.
    static let fieldDriftCycleDuration: CFTimeInterval = 43
    static let reactiveLightCycleDuration: CFTimeInterval = 13.6
    static let signatureSweepCycleDuration: CFTimeInterval = 9.4

    static let entranceScale: CGFloat = 1.014
    static let entranceTranslationY: CGFloat = 7
    static let horizontalParallax: CGFloat = 2.15
    static let verticalParallax: CGFloat = 1.55

    // Direct manipulation remains intentionally microscopic. These values are
    // large enough to be felt at 120 Hz without bending copy or controls.
    static let maximumTouchTranslationX: CGFloat = 3.6
    static let maximumTouchTranslationY: CGFloat = 2.7
    static let maximumTouchRotation: CGFloat = 0.012
    static let reactiveLightTravelRatio: CGFloat = 0.34
    static let touchDepthScale: CGFloat = 0.994
    static let touchLightScale: CGFloat = 1.014
    static let touchLensBaseScale: CGFloat = 0.972
    static let touchLensVelocityBloom: CGFloat = 0.055
    static let touchLensActiveAlpha: CGFloat = 0.52
    static let touchVelocityForMaximumBloom: CGFloat = 1_850
    static let touchSmoothingResponse: CGFloat = 0.31

    static let tapMaximumDuration: TimeInterval = 0.34
    static let tapMaximumTravel: CGFloat = 14

    static var entranceTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.16, y: 0.86),
            controlPoint2: CGPoint(x: 0.24, y: 1)
        )
    }

    static var overlayTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.20, y: 0.82),
            controlPoint2: CGPoint(x: 0.28, y: 1)
        )
    }

    static var ambientTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.37, 0, 0.63, 1)
    }

    static var accentTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
    }

    static var paletteTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.32, 0, 0.18, 1)
    }

    static var signatureSweepTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.18, 0.74, 0.24, 1)
    }
}
