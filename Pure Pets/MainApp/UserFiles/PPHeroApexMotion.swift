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
    static let entranceDuration: TimeInterval = 0.46
    static let overlayEntranceDuration: TimeInterval = 0.30
    static let overlayEntranceDelay: TimeInterval = 0.05
    static let accentTransitionDuration: CFTimeInterval = 0.22
    static let paletteTransitionDuration: CFTimeInterval = 0.42
    static let interactionSettleDuration: TimeInterval = 0.30
    static let fieldDriftCycleDuration: CFTimeInterval = 31
    static let signatureSweepCycleDuration: CFTimeInterval = 4.8

    static let entranceScale: CGFloat = 1.022
    static let entranceTranslationY: CGFloat = 4
    static let horizontalParallax: CGFloat = 2.6
    static let verticalParallax: CGFloat = 1.9
    static let maximumTouchTranslationX: CGFloat = 4.0
    static let maximumTouchTranslationY: CGFloat = 3.0
    static let maximumTouchRotation: CGFloat = 0.018
    static let reactiveLightTravelRatio: CGFloat = 0.20
    static let touchDepthScale: CGFloat = 0.996
    static let touchLightScale: CGFloat = 1.018
    static let touchLensBaseScale: CGFloat = 0.985
    static let touchLensVelocityBloom: CGFloat = 0.035
    static let touchLensActiveAlpha: CGFloat = 0.48
    static let touchVelocityForMaximumBloom: CGFloat = 1_600

    static var entranceTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.22, y: 1),
            controlPoint2: CGPoint(x: 0.36, y: 1)
        )
    }

    static var overlayTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: CGPoint(x: 0.23, y: 1),
            controlPoint2: CGPoint(x: 0.32, y: 1)
        )
    }

    static var ambientTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.45, 0, 0.55, 1)
    }

    static var accentTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
    }

    static var paletteTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.32, 0, 0.18, 1)
    }

    static var signatureSweepTimingFunction: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.20, 0.78, 0.28, 1)
    }

}
