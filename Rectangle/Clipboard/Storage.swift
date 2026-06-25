import Foundation
import SwiftData

@MainActor
class Storage {
  static let shared = Storage()

  var container: ModelContainer
  var context: ModelContext { container.mainContext }
  var size: String {
    guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).allValues.first?.value as? Int64, size > 1 else {
      return ""
    }

    return ByteCountFormatter().string(fromByteCount: size)
  }

  private let url = URL.applicationSupportDirectory.appending(path: "rawm/Storage.sqlite")

  init() {
    // One-time migration: move storage from old Maccy path to rawm path.
    let oldURL = URL.applicationSupportDirectory.appending(path: "Maccy/Storage.sqlite")
    if FileManager.default.fileExists(atPath: oldURL.path) &&
       !FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.moveItem(at: oldURL, to: url)
    }

    var config = ModelConfiguration(url: url)

    #if DEBUG
    if CommandLine.arguments.contains("enable-testing") {
      config = ModelConfiguration(isStoredInMemoryOnly: true)
    }
    #endif

    do {
      container = try ModelContainer(for: HistoryItem.self, configurations: config)
    } catch let error {
      fatalError("Cannot load database: \(error.localizedDescription).")
    }
  }
}
