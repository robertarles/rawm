# Naming Refactor Plan: rawm

Replace all remaining Rectangle, Maccy, and skhd app-name references throughout the codebase with rawm equivalents. The goal is that `grep -ri "rectangle\|maccy\|skhd" .` (excluding `.git` and intentional historical references) returns nothing meaningful.

---

## Do NOT rename

These references are intentional and must stay:

- `com.knollsoft.Rectangle.plist` — `ShortcutMigration.swift:43` reads the user's existing Rectangle preferences to migrate their shortcuts. This is a reference to the *other app*, not to rawm.
- `com.knollsoft.Rectangle` in `AppDelegate.launcherAppId` history / version migration checks — code that checks `intLastVersion < 46/64/72` was shipped with Rectangle and must match its historical bundle version numbers.
- GitHub issue URLs in comments (e.g. `https://github.com/p0deje/Maccy/issues/...`) — informational provenance comments, do not change.
- skhd references in comments — these explain user-facing behavior ("like skhd's `cmd + alt - t`"), not code identifiers.
- `org.p0deje.Maccy` pasteboard type constant — this is a wire-format identifier used to detect clipboard items that originated from Maccy. Changing it would break interoperability. **Keep as a string literal**, but rename the Swift symbol that wraps it (see Tier 1 below).

---

## Tier 1 — Code identifiers (Swift symbols, file names, directories)

These break builds, imports, or runtime behavior if left unrenamed.

### 1.1 Directories and project files

| Current | Rename to |
|---|---|
| `Rectangle/` (source dir) | `Sources/` |
| `RectangleLauncher/` | `Launcher/` |
| `RectangleTests/` | `Tests/` |
| `Rectangle.xcodeproj` | `rawm.xcodeproj` |

> **Note:** Renaming the Xcode project file also requires updating the `.xcworkspace` internal reference and any CI scripts.

### 1.2 Entitlements and bridging header files

| Current | Rename to |
|---|---|
| `Rectangle.entitlements` | `rawm.entitlements` |
| `RectangleRelease.entitlements` | `rawmRelease.entitlements` |
| `RectangleLauncher.entitlements` | `rawmLauncher.entitlements` |
| `RectangleLauncherRelease.entitlements` | `rawmLauncherRelease.entitlements` |
| `Rectangle-Bridging-Header.h` | `rawm-Bridging-Header.h` |

Update file references in `project.pbxproj` accordingly.

### 1.3 Swift class and protocol names

| Current | Rename to | Primary file |
|---|---|---|
| `RectangleDefaults` | `RawmDefaults` | `Defaults.swift` |
| `RectangleDefault` (protocol) | `RawmDefault` | `Defaults.swift` |
| `RectangleLogger` | `RawmLogger` | `Logging/LogViewer.swift` |
| `CycleSizesDefault: RectangleDefault` | `CycleSizesDefault: RawmDefault` | `CycleSize.swift` |
| `SubsequentExecutionDefault: RectangleDefault` | `SubsequentExecutionDefault: RawmDefault` | `SubsequentExecutionMode.swift` |
| All `BoolDefault`, `StringDefault`, etc. `: RectangleDefault` | `: RawmDefault` | `Defaults.swift` |

`RectangleDefaults` is used throughout ~40 files. Use project-wide rename in Xcode or `sed`.

### 1.4 Maccy clipboard identifiers

| Current | Rename to | File |
|---|---|---|
| `MenuIcon.maccy` (enum case) | `MenuIcon.rawm` | `Clipboard/MenuIcon.swift` |
| `.fromMaccy` (NSPasteboard type symbol) | `.fromRawm` | `Clipboard/Extensions/NSPasteboard.PasteboardType+Types.swift` |
| `NSPasteboardType.fromMaccy` usages | `.fromRawm` | `Clipboard/Models/HistoryItem.swift`, `Clipboard/Clipboard.swift` |
| `NSImage.maccyStatusBar` | `NSImage.rawmStatusBar` | `Clipboard/Extensions/NSImage+Names.swift` |

> The *value* of `.fromRawm` stays `"org.p0deje.Maccy"` — only the Swift symbol name changes (see Do Not Rename above).

### 1.5 Default value references

| Current | Rename to | File |
|---|---|---|
| `Key<MenuIcon>("menuIcon", default: .maccy)` | `default: .rawm` | `Clipboard/Extensions/Defaults.Keys+Names.swift` |

---

## Tier 2 — User-visible strings and storage paths

These affect what the user sees or where data is stored on disk.

### 2.1 Storage path

| Current | Rename to | File |
|---|---|---|
| `"Maccy/Storage.sqlite"` | `"rawm/Storage.sqlite"` | `Clipboard/Storage.swift:18` |

> **Migration note:** On first launch after this change, existing clipboard history stored at `~/Library/Application Support/Maccy/Storage.sqlite` will not be found. Add a one-time migration step that moves/copies the file to the new path before the store is opened.

### 2.2 User-facing UI text

| Current | Replace with | File |
|---|---|---|
| `Text("Maccy")` header in clipboard popup | `Text("Clipboard")` | `Clipboard/Views/ListHeaderView.swift:17` |

### 2.3 Logger labels (visible in Console.app)

| Current | Rename to | File |
|---|---|---|
| `Logger(label: "org.p0deje.Maccy")` | `Logger(label: "com.robertarles.rawm")` | `Clipboard/Observables/History.swift:14` |
| `Logger(label: "org.p0deje.Maccy")` | `Logger(label: "com.robertarles.rawm")` | `Clipboard/Observables/SlideoutController.swift:67` |

### 2.4 Storyboard strings in RectangleLauncher

File: `RectangleLauncher/Base.lproj/Main.storyboard`

| Current | Replace with |
|---|---|
| `"RectangleLauncher"` (menu bar app menu title) | `"rawmLauncher"` |
| `"About RectangleLauncher"` | `"About rawmLauncher"` |
| `"Hide RectangleLauncher"` | `"Hide rawmLauncher"` |
| `"Quit RectangleLauncher"` | `"Quit rawmLauncher"` |
| `"RectangleLauncher Help"` | `"rawmLauncher Help"` |
| `customModule="RectangleLauncher"` | `customModule="rawmLauncher"` |

### 2.5 Log viewer window title

File: `Logging/LogViewer.storyboard`

| Current | Replace with |
|---|---|
| `title="Rectangle Logging"` | `title="rawm Logging"` |

### 2.6 Info.plist and policy files

| File | Key/field | Current | Replace with |
|---|---|---|---|
| `Rectangle/Info.plist` | Copyright string | `"Built on Rectangle by Ryan Hanson"` | `"rawm — built on Rectangle (Ryan Hanson) and Maccy (Alex Rodionov)"` |
| `Rectangle/InternetAccessPolicy.plist` | App description | `"Rectangle is the gold standard…"` | `"rawm is a window manager and clipboard manager for macOS"` |
| `Rectangle/InternetAccessPolicy.plist` | Update check description | `"Rectangle checks for new versions"` | `"rawm checks for new versions"` |
| `Rectangle/InternetAccessPolicy.plist` | URL | `rectangleapp.com` | `(remove or update to rawm's own URL when available)` |

### 2.7 Image asset files

| Current | Rename to | Location |
|---|---|---|
| `RectangleStatusTemplate.png` | `RawmStatusTemplate.png` | `Assets.xcassets/StatusTemplate.imageset/` |
| `RectangleStatusTemplate22.png` | `RawmStatusTemplate22.png` | same |
| `RectangleStatusTemplate44.png` | `RawmStatusTemplate44.png` | same |

Update `Contents.json` in the imageset to reference the new filenames.

---

## Tier 3 — Comments and documentation

These have no runtime effect but improve maintainability. Do as a final pass.

- Replace "Maccy-derived" with "clipboard subsystem" in file-header comments.
- Replace "skhd-style" with "shell action" in comments where it describes a feature (not the migration source).
- Replace "Rectangle" with "rawm" in comments that describe rawm's own behavior (not attribution).
- Retain attribution comments like `// Adapted from Rectangle by Ryan Hanson` and `// Adapted from Maccy by Alex Rodionov` — credit where due.

---

## Xcode project.pbxproj changes

The `project.pbxproj` will need mechanical updates for:

1. **Target names**: `Rectangle` → `rawm`, `RectangleLauncher` → `rawmLauncher`, `RectangleTests` → `rawmTests`
2. **Group/folder names** in the file tree
3. **Build setting** `PRODUCT_NAME` for each target
4. **File references** for renamed entitlements and bridging header
5. **Scheme file** in `Rectangle.xcodeproj/xcshareddata/xcschemes/` — rename `rawm.xcscheme` path references

---

## Suggested execution order

1. **Snapshot**: commit current working state before starting.
2. **Directory and project rename**: rename dirs and `.xcodeproj` first; this is the highest-risk step and touches `.pbxproj` most heavily. Do this in Xcode (File → Rename) or carefully with `git mv`.
3. **Swift symbol rename**: use Xcode's project-wide rename for `RectangleDefaults` → `RawmDefaults` and `RectangleDefault` → `RawmDefault`; then rename `RectangleLogger`, Maccy symbols.
4. **Entitlements and bridging header**: rename files and update `.pbxproj` references.
5. **Storage path + migration step**: update `Storage.swift` and add the one-time file-move migration.
6. **Storyboard strings**: edit storyboard XML directly.
7. **Plists and assets**: update `Info.plist`, `InternetAccessPolicy.plist`, image files.
8. **Comments**: final sweep.
9. **Build and test**: ensure `make build` succeeds, app launches, clipboard history loads, shortcuts work.
10. **Verify**: `grep -ri "rectangle\|maccy" --include="*.swift" --include="*.plist" --include="*.storyboard" .` should return only intentional references (the `com.knollsoft.Rectangle.plist` migration read and attribution comments).
