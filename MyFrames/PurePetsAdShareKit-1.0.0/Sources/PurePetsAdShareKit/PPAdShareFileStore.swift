import Foundation

public struct PPAdShareFileStore: Sendable {
  public let rootDirectory: URL

  public init(
    rootDirectory: URL = FileManager.default.temporaryDirectory
      .appendingPathComponent("PurePetsAdShares", isDirectory: true)
  ) {
    self.rootDirectory = rootDirectory.standardizedFileURL
  }

  public func fileURL(forAdvertisementID advertisementID: String) -> URL {
    let digest = Self.fnv1a64(advertisementID)
    return
      rootDirectory
      .appendingPathComponent("pure-pets-ad-\(digest)")
      .appendingPathExtension("jpg")
  }

  @discardableResult
  public func writeJPEG(
    _ data: Data,
    advertisementID: String
  ) throws -> URL {
    do {
      try FileManager.default.createDirectory(
        at: rootDirectory,
        withIntermediateDirectories: true
      )
      let destination = fileURL(forAdvertisementID: advertisementID)
      try data.write(to: destination, options: .atomic)
      return destination
    } catch {
      throw PPAdShareError.temporaryFileWriteFailed
    }
  }

  public func removeFile(at fileURL: URL) {
    guard contains(fileURL) else { return }
    try? FileManager.default.removeItem(at: fileURL)
  }

  public func removeFiles(
    olderThan maximumAge: TimeInterval,
    now: Date = Date()
  ) {
    guard maximumAge >= 0 else { return }
    let keys: Set<URLResourceKey> = [
      .contentModificationDateKey,
      .creationDateKey,
      .isRegularFileKey,
    ]
    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: rootDirectory,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsHiddenFiles]
      )
    else {
      return
    }

    for fileURL in files where contains(fileURL) && fileURL.pathExtension == "jpg" {
      guard let values = try? fileURL.resourceValues(forKeys: keys),
        values.isRegularFile == true,
        let fileDate = values.contentModificationDate ?? values.creationDate,
        now.timeIntervalSince(fileDate) > maximumAge
      else {
        continue
      }
      try? FileManager.default.removeItem(at: fileURL)
    }
  }

  public func removeAll() {
    try? FileManager.default.removeItem(at: rootDirectory)
  }

  private func contains(_ fileURL: URL) -> Bool {
    fileURL.deletingLastPathComponent().standardizedFileURL == rootDirectory
  }

  private static func fnv1a64(_ value: String) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 0x100_0000_01b3
    }
    return String(format: "%016llx", hash)
  }
}
