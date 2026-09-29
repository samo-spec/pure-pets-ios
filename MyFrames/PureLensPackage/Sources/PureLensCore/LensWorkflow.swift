import Foundation

public enum LensFailureKind: String, Equatable, Sendable {
    case camera
    case network
    case noResult
    case safety
    case action
    case unknown
}

public struct LensFailure: Error, Equatable, Sendable {
    public var kind: LensFailureKind
    public var message: String
    public var canRetry: Bool

    public init(kind: LensFailureKind, message: String, canRetry: Bool = true) {
        self.kind = kind
        self.message = message
        self.canRetry = canRetry
    }
}

public enum LensWorkflowState: Equatable, Sendable {
    case permission(LensCameraAuthorization)
    case ready
    case scanning
    case resolving
    case insight(LensInsight)
    case executing(LensInsight)
    case success(LensActionReceipt)
    case failure(LensFailure)
}

public enum LensWorkflowEvent: Equatable, Sendable {
    case cameraAuthorizationChanged(LensCameraAuthorization)
    case startScanning
    case startResolving
    case resolved(LensInsight)
    case execute
    case executed(LensActionReceipt)
    case failed(LensFailure)
    case cancel
    case retry
}

public enum LensWorkflowTransitionError: Error, Equatable, Sendable {
    case invalid(state: String, event: String)
}

public struct LensWorkflow: Equatable, Sendable {
    public private(set) var state: LensWorkflowState

    public init(state: LensWorkflowState = .permission(.notDetermined)) {
        self.state = state
    }

    public mutating func send(_ event: LensWorkflowEvent) throws {
        switch (state, event) {
        case (_, .cameraAuthorizationChanged(.authorized)):
            state = .ready
        case (_, .cameraAuthorizationChanged(let value)):
            state = .permission(value)
        case (.ready, .startScanning), (.failure, .retry):
            state = .scanning
        case (.scanning, .startResolving):
            state = .resolving
        case (.resolving, .resolved(let insight)):
            state = .insight(insight)
        case (.insight(let insight), .execute):
            state = .executing(insight)
        case (.executing, .executed(let receipt)):
            state = .success(receipt)
        case (_, .failed(let failure)):
            state = .failure(failure)
        case (.scanning, .cancel), (.resolving, .cancel), (.insight, .cancel), (.success, .cancel), (.failure, .cancel):
            state = .ready
        default:
            throw LensWorkflowTransitionError.invalid(
                state: String(describing: state),
                event: String(describing: event)
            )
        }
    }
}
