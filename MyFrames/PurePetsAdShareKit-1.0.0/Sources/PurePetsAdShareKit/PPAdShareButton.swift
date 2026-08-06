#if canImport(SwiftUI) && canImport(UIKit) && canImport(LinkPresentation)
  import SwiftUI

  @available(iOS 17.0, *)
  public enum PPAdShareButtonPhase: Equatable, Sendable {
    case idle
    case preparing
  }

  @available(iOS 17.0, *)
  public struct PPAdShareButton<Label: View>: View {
    public let payload: PPAdSharePayload
    public let imageSource: PPAdShareImageSource?

    private let explicitCopy: PPAdShareCopy?
    private let coordinator: PPAdShareCoordinator
    private let label: (PPAdShareButtonPhase, PPAdShareCopy) -> Label

    @Environment(\.locale) private var locale
    @State private var phase: PPAdShareButtonPhase = .idle
    @State private var session: PPAdShareSession?
    @State private var failure: FailurePresentation?
    @State private var preparationTask: Task<Void, Never>?

    public init(
      payload: PPAdSharePayload,
      imageSource: PPAdShareImageSource? = nil,
      configuration: PPAdShareConfiguration = .purePets,
      copy: PPAdShareCopy? = nil,
      imageLoader: any PPAdShareImageLoading = PPAdShareImageLoader(),
      renderer: PPAdShareCardRenderer = PPAdShareCardRenderer(),
      analytics: any PPAdShareAnalytics = PPNoopAdShareAnalytics.shared,
      @ViewBuilder label:
        @escaping (
          PPAdShareButtonPhase,
          PPAdShareCopy
        ) -> Label
    ) {
      self.payload = payload
      self.imageSource = imageSource
      self.explicitCopy = copy
      self.coordinator = PPAdShareCoordinator(
        configuration: configuration,
        imageLoader: imageLoader,
        renderer: renderer,
        analytics: analytics
      )
      self.label = label
    }

    public var body: some View {
      Button(action: prepareShare) {
        label(phase, resolvedCopy)
      }
      .buttonStyle(PPAdSharePressButtonStyle())
      .disabled(phase == .preparing)
      .accessibilityLabel(resolvedCopy.buttonTitle)
      .accessibilityHint(resolvedCopy.buttonAccessibilityHint)
      .accessibilityValue(
        phase == .preparing ? resolvedCopy.preparingTitle : ""
      )
      .accessibilityIdentifier("purepets.adshare.button")
      .sheet(item: $session) { preparedSession in
        PPShareSheet(
          session: preparedSession,
          coordinator: coordinator
        ) {
          session = nil
        }
        .ignoresSafeArea()
      }
      .onDisappear {
        guard phase == .preparing else { return }
        preparationTask?.cancel()
      }
      .alert(
        resolvedCopy.failureTitle,
        isPresented: failureIsPresented
      ) {
        Button(resolvedCopy.dismissTitle) {
          failure = nil
        }
      } message: {
        if let failure {
          Text(failure.message)
        }
      }
    }

    private var resolvedCopy: PPAdShareCopy {
      explicitCopy ?? .forLocale(locale)
    }

    private var failureIsPresented: Binding<Bool> {
      Binding(
        get: { failure != nil },
        set: { isPresented in
          if !isPresented {
            failure = nil
          }
        }
      )
    }

    private func prepareShare() {
      guard phase == .idle else { return }
      preparationTask?.cancel()
      phase = .preparing
      let copy = resolvedCopy

      preparationTask = Task { @MainActor in
        defer { preparationTask = nil }
        do {
          let preparedSession = try await coordinator.prepare(
            payload: payload,
            imageSource: imageSource,
            copy: copy
          )
          try Task.checkCancellation()
          phase = .idle
          session = preparedSession
        } catch is CancellationError {
          phase = .idle
        } catch {
          phase = .idle
          failure = FailurePresentation(
            message: (error as? LocalizedError)?.errorDescription
              ?? error.localizedDescription
          )
        }
      }
    }
  }

  @available(iOS 17.0, *)
  extension PPAdShareButton where Label == PPFancyShareLabel {
    public init(
      payload: PPAdSharePayload,
      imageSource: PPAdShareImageSource? = nil,
      configuration: PPAdShareConfiguration = .purePets,
      copy: PPAdShareCopy? = nil,
      imageLoader: any PPAdShareImageLoading = PPAdShareImageLoader(),
      renderer: PPAdShareCardRenderer = PPAdShareCardRenderer(),
      analytics: any PPAdShareAnalytics = PPNoopAdShareAnalytics.shared
    ) {
      self.init(
        payload: payload,
        imageSource: imageSource,
        configuration: configuration,
        copy: copy,
        imageLoader: imageLoader,
        renderer: renderer,
        analytics: analytics
      ) { phase, resolvedCopy in
        PPFancyShareLabel(
          copy: resolvedCopy,
          brandColor: configuration.brandColor,
          isPreparing: phase == .preparing
        )
      }
    }
  }

  @available(iOS 17.0, *)
  private struct FailurePresentation {
    let message: String
  }

  @available(iOS 17.0, *)
  private struct PPAdSharePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .scaleEffect(
          configuration.isPressed && !reduceMotion ? 0.975 : 1
        )
        .opacity(configuration.isPressed ? 0.82 : 1)
        .animation(
          reduceMotion ? nil : .snappy(duration: 0.18),
          value: configuration.isPressed
        )
    }
  }
#endif
