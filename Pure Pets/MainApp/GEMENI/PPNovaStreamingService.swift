//
//  PPNovaStreamingService.swift
//  Pure Pets
//
//  Streaming consumer for novaGenkitChat. Uses Firebase Functions Swift SDK
//  typed Callable<..., StreamResponse<...>> to receive metadata first (so
//  cards render immediately) then text deltas as Gemini produces them.
//
//  Coexists with the non-streaming PPNovaGenkitService — call sites pick
//  which to use based on a feature flag.
//

import Foundation
import FirebaseFunctions

// MARK: - JSON bridge

/// `JSONObject` is the bridge between Firebase's Codable streaming API and
/// our loose-typed `[String: Any]` ObjC dictionary world. Nova's metadata
/// has many optional fields and evolves over time; modeling each as a
/// concrete Codable property would be fragile. Instead we round-trip
/// through a JSONValue enum and surface the raw `[String: Any]` to ObjC.
public struct JSONObject: Codable, @unchecked Sendable {
    public let raw: [String: Any]

    public init(_ raw: [String: Any]) {
        self.raw = raw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(JSONValue.self)
        if case let .object(dict) = value {
            self.raw = dict.mapValues { $0.asAny }
        } else {
            self.raw = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(JSONValue.from(raw))
    }
}

indirect enum JSONValue: Codable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                .init(codingPath: container.codingPath,
                      debugDescription: "Unsupported JSON value")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:           try container.encodeNil()
        case .bool(let v):    try container.encode(v)
        case .number(let v):  try container.encode(v)
        case .string(let v):  try container.encode(v)
        case .array(let v):   try container.encode(v)
        case .object(let v):  try container.encode(v)
        }
    }

    static func from(_ any: Any) -> JSONValue {
        if any is NSNull { return .null }
        if let value = any as? Bool { return .bool(value) }
        if let value = any as? Int { return .number(Double(value)) }
        if let value = any as? Double { return .number(value) }
        if let value = any as? String { return .string(value) }
        if let value = any as? [Any] { return .array(value.map { JSONValue.from($0) }) }
        if let value = any as? [String: Any] { return .object(value.mapValues { JSONValue.from($0) }) }
        return .null
    }

    static func from(_ dict: [String: Any]) -> JSONValue {
        return .object(dict.mapValues { JSONValue.from($0) })
    }

    var asAny: Any {
        switch self {
        case .null:          return NSNull()
        case .bool(let v):   return v
        case .number(let v): return v
        case .string(let v): return v
        case .array(let v):  return v.map { $0.asAny }
        case .object(let v): return v.mapValues { $0.asAny }
        }
    }
}

// MARK: - Streaming service

@MainActor
@objc public class PPNovaStreamingService: NSObject {
    @objc public static let shared = PPNovaStreamingService()

    private let functions: Functions

    override init() {
        self.functions = Functions.functions(region: "us-central1")
        super.init()
    }

    /// Sends a Nova chat message and consumes the streaming response.
    /// Callbacks fire on the main thread.
    ///
    /// - `onMetadata`: fires once before any text — carries the card IDs and
    ///   options so the UI can render cards immediately.
    /// - `onTextDelta`: fires multiple times as Gemini streams text tokens.
    /// - `onComplete`: fires once at the end with the full final text +
    ///   metadata. On failure, only `error` is non-nil.
    @objc public func sendMessage(
        _ message: String,
        sessionId: String?,
        language: String,
        context: NSDictionary?,
        onMetadata: @escaping (NSDictionary) -> Void,
        onTextDelta: @escaping (NSString) -> Void,
        onComplete: @escaping (NSString?, NSDictionary?, NSError?) -> Void
    ) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            let error = NSError(
                domain: "PPNovaStreamingService",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Nova message is required."]
            )
            onComplete(nil, nil, error)
            return
        }
        let normalizedLanguage = language == "en" ? "en" : "ar"
        let trimmedSessionId = sessionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var requestDict: [String: Any] = [
            "message": trimmedMessage,
            "language": normalizedLanguage,
        ]
        if !trimmedSessionId.isEmpty {
            requestDict["sessionId"] = trimmedSessionId
        }
        if let context = context as? [String: Any] {
            requestDict["context"] = context
        }

        let request = JSONObject(requestDict)
        let callable: Callable<JSONObject, StreamResponse<JSONObject, JSONObject>> =
            functions.httpsCallable("novaGenkitChat")

        Task {
            do {
                let stream = try callable.stream(request)
                var receivedResult = false

                for try await response in stream {
                    switch response {
                    case let .message(chunk):
                        await Self.handleChunk(
                            chunk.raw,
                            onMetadata: onMetadata,
                            onTextDelta: onTextDelta
                        )
                    case let .result(result):
                        receivedResult = true
                        let text: NSString? = (result.raw["text"] as? String).map { $0 as NSString }
                        let metadata: NSDictionary? =
                            (result.raw["metadata"] as? [String: Any]).map { $0 as NSDictionary }
                        await MainActor.run {
                            onComplete(text, metadata, nil)
                        }
                    }
                }

                // Stream ended without a final `.result` — surface the absence
                // rather than leave the completion handler stranded.
                if !receivedResult {
                    await MainActor.run {
                        onComplete(nil, nil, nil)
                    }
                }
            } catch {
                let nsError = error as NSError
                await MainActor.run {
                    onComplete(nil, nil, nsError)
                }
            }
        }
    }

    /// Dispatches a single message chunk to the appropriate callback.
    /// Runs on the main actor so UI callbacks are thread-safe.
    @MainActor
    private static func handleChunk(
        _ chunk: [String: Any],
        onMetadata: (NSDictionary) -> Void,
        onTextDelta: (NSString) -> Void
    ) {
        let type = chunk["type"] as? String ?? ""
        switch type {
        case "metadata":
            if let metadata = chunk["metadata"] as? [String: Any] {
                onMetadata(metadata as NSDictionary)
            }
        case "text":
            if let delta = chunk["textDelta"] as? String, !delta.isEmpty {
                onTextDelta(delta as NSString)
            }
        default:
            break
        }
    }
}
