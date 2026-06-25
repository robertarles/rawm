import AppKit
import Defaults

enum MenuIcon: String, CaseIterable, Identifiable, Defaults.Serializable {
  case rawm
  case clipboard
  case scissors
  case paperclip

  var id: Self { self }

  var image: NSImage {
    switch self {
    case .rawm:
      return NSImage(named: .rawmStatusBar)!
    case .clipboard:
      return NSImage(named: .clipboard)!
    case .scissors:
      return NSImage(named: .scissors)!
    case .paperclip:
      return NSImage(named: .paperclip)!
    }
  }
}
