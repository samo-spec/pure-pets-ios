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
    // The entrance reads as optical focus, not travel. The overlay resolves
    // slightly after the field so the edge treatment never arrives first.
    static let entranceDuration: TimeInterval = 0.48
    static let overlayEntranceDuration: TimeInterval = 0.34
    static let overlayEntranceDelay: TimeInterval = 0.045

    // Full Screen enters as a field coming into focus. Its smaller transform
    // and longer resolve avoid a page-wide zoom behind already-readable copy.
    static let fullScreenEntranceDuration: TimeInterval = 0.62
    static let fullScreenEntranceScale: CGFloat = 1.004
    static let fullScreenEntranceTranslationY: CGFloat = 2

    // Optical state changes use one family of curves, so accent, palette and
    // interaction updates feel authored by the same motion system.
    static let accentTransitionDuration: CFTimeInterval = 0.30
    static let paletteTransitionDuration: CFTimeInterval = 0.46
    static let interactionSettleDuration: TimeInterval = 0.48
    static let tapPulseDuration: CFTimeInterval = 0.56
    static let contactWaveDuration: CFTimeInterval = 0.68

    // Ambient cycles are deliberately incommensurate. No two major fields
    // return to their starting phase together during a normal reading session.
    static let fieldDriftCycleDuration: CFTimeInterval = 52
    static let reactiveLightCycleDuration: CFTimeInterval = 18.4
    static let signatureSweepCycleDuration: CFTimeInterval = 12.8
    static let fullScreenFieldCycleDuration: CFTimeInterval = 93.1
    static let fullScreenSurfaceCycleDuration: CFTimeInterval = 107.3
    static let fullScreenPrismCycleDuration: CFTimeInterval = 119.9
    static let fullScreenReactiveLightCycleDuration: CFTimeInterval = 47.3
    static let fullScreenParticleBaseCycleDuration: CFTimeInterval = 59.9
    static let fullScreenParticleCycleStep: CFTimeInterval = 11.2
    static let compactPrismCycleDuration: CFTimeInterval = 73.1
    static let particleBaseCycleDuration: CFTimeInterval = 27.4
    static let particleCycleStep: CFTimeInterval = 5.1
    static let fingerPresenceCycleDuration: CFTimeInterval = 1.72

    // BB Base Background is the long-lived canvas behind many screens. Its
    // care fields should feel alive on ProMotion hardware without reading as a
    // moving decoration or reducing text stability.
    static let baseBackgroundFieldCycleDuration: CFTimeInterval = 76.0
    static let baseBackgroundPrismCycleDuration: CFTimeInterval = 96.0
    static let baseBackgroundReactiveLightCycleDuration: CFTimeInterval = 31.0

    static let entranceScale: CGFloat = 1.009
    static let entranceTranslationY: CGFloat = 5
    static let horizontalParallax: CGFloat = 1.8
    static let verticalParallax: CGFloat = 1.3
    static let fullScreenHorizontalParallax: CGFloat = 1.1
    static let fullScreenVerticalParallax: CGFloat = 0.8

    // Direct manipulation remains intentionally microscopic. These values are
    // large enough to be felt at 120 Hz without bending copy or controls.
    static let maximumTouchTranslationX: CGFloat = 3.2
    static let maximumTouchTranslationY: CGFloat = 2.4
    static let maximumTouchRotation: CGFloat = 0.0095
    static let reactiveLightTravelRatio: CGFloat = 0.30
    static let touchDepthScale: CGFloat = 0.995
    static let touchLightScale: CGFloat = 1.012
    static let touchLensBaseScale: CGFloat = 0.978
    static let touchLensVelocityBloom: CGFloat = 0.045
    static let touchLensActiveAlpha: CGFloat = 0.44
    static let touchVelocityForMaximumBloom: CGFloat = 2_100
    static let touchSmoothingResponse: CGFloat = 0.265
    static let fullScreenTouchResponseIntensity: CGFloat = 0.72

    static let tapMaximumDuration: TimeInterval = 0.30
    static let tapMaximumTravel: CGFloat = 12

    static var entranceTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.16, y: 1),
            controlPoint2: CGPoint(x: 0.30, y: 1)
        )
    }

    static var overlayTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.22, y: 0.78),
            controlPoint2: CGPoint(x: 0.28, y: 1)
        )
    }

    static var ambientTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.45, 0, 0.55, 1)
    }

    static var accentTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.20, 0.90, 0.25, 1)
    }

    static var paletteTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.22, 0.61, 0.36, 1)
    }

    static var signatureSweepTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.22, 0.78, 0.24, 1)
    }
}
