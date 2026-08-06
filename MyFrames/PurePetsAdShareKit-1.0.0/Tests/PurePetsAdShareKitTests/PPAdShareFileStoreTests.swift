import Foundation
import XCTest

@testable import PurePetsAdShareKit

final class PPAdShareFileStoreTests: XCTestCase {
  func testFileURLCannotEscapeShareDirectory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PPAdShareFileStore(rootDirectory: root)

    let fileURL = store.fileURL(forAdvertisementID: "../../private/customer@email.com")

    XCTAssertEqual(
      fileURL.deletingLastPathComponent().standardizedFileURL, root.standardizedFileURL)
    XCTAssertEqual(fileURL.pathExtension, "jpg")
    XCTAssertFalse(fileURL.lastPathComponent.contains(".."))
    XCTAssertFalse(fileURL.lastPathComponent.contains("@"))
    XCTAssertFalse(fileURL.lastPathComponent.contains("customer"))
  }

  func testFileNameIsDeterministicForSameAdvertisement() {
    let root = URL(fileURLWithPath: "/tmp/pure-pets-test", isDirectory: true)
    let store = PPAdShareFileStore(rootDirectory: root)

    XCTAssertEqual(
      store.fileURL(forAdvertisementID: "ad-2048"),
      store.fileURL(forAdvertisementID: "ad-2048")
    )
    XCTAssertNotEqual(
      store.fileURL(forAdvertisementID: "ad-2048"),
      store.fileURL(forAdvertisementID: "ad-2049")
    )
  }

  func testExpiredFilesAreRemovedWithoutTouchingRecentFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PPAdShareFileStore(rootDirectory: root)
    let oldURL = try store.writeJPEG(Data([1]), advertisementID: "old")
    let recentURL = try store.writeJPEG(Data([2]), advertisementID: "recent")
    let now = Date(timeIntervalSince1970: 10_000)

    try FileManager.default.setAttributes(
      [.modificationDate: now.addingTimeInterval(-7_200)],
      ofItemAtPath: oldURL.path
    )
    try FileManager.default.setAttributes(
      [.modificationDate: now.addingTimeInterval(-60)],
      ofItemAtPath: recentURL.path
    )

    store.removeFiles(olderThan: 3_600, now: now)

    XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: recentURL.path))
  }

  func testWriteAndRemoveLifecycle() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = PPAdShareFileStore(rootDirectory: root)
    let data = Data([0xFF, 0xD8, 0xFF, 0xD9])

    let url = try store.writeJPEG(data, advertisementID: "ad-1")
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    XCTAssertEqual(try Data(contentsOf: url), data)

    store.removeFile(at: url)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }
}
