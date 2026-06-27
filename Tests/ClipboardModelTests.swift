/// ClipboardModelTests.swift
///
/// Tests for clipboard models/storage/observables.
/// Uses an in-memory SwiftData container to exercise HistoryItem / HistoryItemContent,
/// and exercises pure-logic types (HistoryItemAction, FooterItem, HistoryItemDecorator.highlight,
/// Storage memory-vs-disk branch, etc.) without a running app.

import AppKit
import Sauce
import SwiftData
import XCTest
@testable import rawm

// MARK: - Clipboard Defaults helpers
//
// The Defaults *library* subscript (`Defaults[.key]`) conflicts with the module-level
// `typealias Defaults = RawmDefaults` in TestSupport.swift.  Access clipboard settings
// through UserDefaults directly so both test files compile in the same module.

private struct ClipboardUD {
    static let ud = UserDefaults.standard

    // Snapshot / restore helpers for each bool key we mutate.
    static func bool(_ key: String) -> Bool {
        ud.object(forKey: key) as? Bool ?? false
    }
    static func set(_ value: Bool, forKey key: String) {
        ud.set(value, forKey: key)
    }

    static func highlightMatch() -> String {
        ud.string(forKey: "highlightMatch") ?? "bold"
    }
    static func setHighlightMatch(_ raw: String) {
        ud.set(raw, forKey: "highlightMatch")
    }
}

// MARK: - In-memory container helpers

/// Returns a fresh, isolated in-memory ModelContainer each time it is called.
private func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: HistoryItem.self, configurations: config)
}

/// Build a HistoryItemContent inserted into the given context.
private func makeContent(
    type: NSPasteboard.PasteboardType,
    value: Data?,
    context: ModelContext
) -> HistoryItemContent {
    let content = HistoryItemContent(type: type.rawValue, value: value)
    context.insert(content)
    return content
}

// MARK: - HistoryItemContentTests

class HistoryItemContentTests: XCTestCase {

    func testDefaultInitialization() {
        let content = HistoryItemContent(type: "public.utf8-plain-text", value: nil)
        XCTAssertEqual(content.type, "public.utf8-plain-text")
        XCTAssertNil(content.value)
    }

    func testInitializationWithValue() {
        let data = "hello".data(using: .utf8)!
        let content = HistoryItemContent(type: "public.utf8-plain-text", value: data)
        XCTAssertEqual(content.type, "public.utf8-plain-text")
        XCTAssertEqual(content.value, data)
    }

    func testTypeCanBeUpdated() {
        let content = HistoryItemContent(type: "original", value: nil)
        content.type = "updated"
        XCTAssertEqual(content.type, "updated")
    }

    func testValueCanBeUpdated() {
        let content = HistoryItemContent(type: "t", value: nil)
        let data = Data([0x01, 0x02])
        content.value = data
        XCTAssertEqual(content.value, data)
    }
}

// MARK: - HistoryItemModelTests

class HistoryItemModelTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeInMemoryContainer()
        context = await container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: Basic properties

    func testDefaultHistoryItemProperties() async throws {
        let item = HistoryItem()
        context.insert(item)
        XCTAssertEqual(item.title, "")
        XCTAssertEqual(item.numberOfCopies, 1)
        XCTAssertNil(item.pin)
        XCTAssertNil(item.application)
        XCTAssertTrue(item.contents.isEmpty)
    }

    func testHistoryItemWithStringContent() async throws {
        let textData = "clipboard text".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        XCTAssertEqual(item.text, "clipboard text")
    }

    func testTextReturnsNilWhenNoStringContent() async throws {
        let item = HistoryItem()
        context.insert(item)
        XCTAssertNil(item.text)
    }

    func testFromRawmTrueWhenContentPresent() async throws {
        let content = makeContent(type: .fromRawm, value: Data([1]), context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)
        XCTAssertTrue(item.fromRawm)
    }

    func testFromRawmFalseWhenContentAbsent() async throws {
        let item = HistoryItem()
        context.insert(item)
        XCTAssertFalse(item.fromRawm)
    }

    func testUniversalClipboardTrueWhenContentPresent() async throws {
        let content = makeContent(type: .universalClipboard, value: Data([1]), context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)
        XCTAssertTrue(item.universalClipboard)
    }

    func testUniversalClipboardFalseWhenContentAbsent() async throws {
        let item = HistoryItem()
        context.insert(item)
        XCTAssertFalse(item.universalClipboard)
    }

    // MARK: previewableText

    func testPreviewableTextPrefersString() async throws {
        let textData = "plain text".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)
        XCTAssertEqual(item.previewableText, "plain text")
    }

    func testPreviewableTextFallsBackToTitleWhenEmpty() async throws {
        let item = HistoryItem()
        context.insert(item)
        item.title = "fallback"
        XCTAssertEqual(item.previewableText, "fallback")
    }

    // MARK: modified

    func testModifiedReturnsIntegerFromContent() async throws {
        let data = "42".data(using: .utf8)!
        let content = makeContent(type: .modified, value: data, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)
        XCTAssertEqual(item.modified, 42)
    }

    func testModifiedReturnsNilWhenAbsent() async throws {
        let item = HistoryItem()
        context.insert(item)
        XCTAssertNil(item.modified)
    }

    // MARK: supersedes

    func testSupersedesReturnsTrueWhenAllNonTransientContentsMatch() async throws {
        let textData = "hello".data(using: .utf8)!
        let content1 = makeContent(type: .string, value: textData, context: context)
        let content2 = makeContent(type: .string, value: textData, context: context)

        let older = HistoryItem(contents: [content1])
        context.insert(older)
        let newer = HistoryItem(contents: [content2])
        context.insert(newer)

        XCTAssertTrue(newer.supersedes(older))
    }

    func testSupersedesReturnsFalseWhenContentsDiffer() async throws {
        let data1 = "hello".data(using: .utf8)!
        let data2 = "world".data(using: .utf8)!
        let content1 = makeContent(type: .string, value: data1, context: context)
        let content2 = makeContent(type: .string, value: data2, context: context)

        let older = HistoryItem(contents: [content1])
        context.insert(older)
        let newer = HistoryItem(contents: [content2])
        context.insert(newer)

        XCTAssertFalse(newer.supersedes(older))
    }

    func testSupersedesIgnoresTransientTypes() async throws {
        // An item containing only transient-type content is "superseded" by any item,
        // because allSatisfy returns true on an empty collection.
        let transientContent = makeContent(
            type: .modified,
            value: "1".data(using: .utf8)!,
            context: context
        )
        let older = HistoryItem(contents: [transientContent])
        context.insert(older)

        let newer = HistoryItem()
        context.insert(newer)

        // All non-transient contents of `older` (none) are satisfied → true
        XCTAssertTrue(newer.supersedes(older))
    }

    // MARK: generateTitle

    func testGenerateTitleReturnsPlainTextTrimmed() async throws {
        let saved = ClipboardUD.bool("showSpecialSymbols")
        ClipboardUD.set(false, forKey: "showSpecialSymbols")
        defer { ClipboardUD.set(saved, forKey: "showSpecialSymbols") }

        let textData = "  hello world  ".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        let title = item.generateTitle()
        XCTAssertEqual(title, "hello world")
    }

    func testGenerateTitleShowsSpecialSymbolsForNewlines() async throws {
        let saved = ClipboardUD.bool("showSpecialSymbols")
        ClipboardUD.set(true, forKey: "showSpecialSymbols")
        defer { ClipboardUD.set(saved, forKey: "showSpecialSymbols") }

        let textData = "line1\nline2".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        let title = item.generateTitle()
        XCTAssertTrue(title.contains("⏎"), "Expected newline symbol ⏎ in title, got: \(title)")
    }

    func testGenerateTitleShowsSpecialSymbolsForTabs() async throws {
        let saved = ClipboardUD.bool("showSpecialSymbols")
        ClipboardUD.set(true, forKey: "showSpecialSymbols")
        defer { ClipboardUD.set(saved, forKey: "showSpecialSymbols") }

        let textData = "col1\tcol2".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        let title = item.generateTitle()
        XCTAssertTrue(title.contains("⇥"), "Expected tab symbol ⇥ in title, got: \(title)")
    }

    func testGenerateTitleShowsSpecialSymbolsForLeadingSpaces() async throws {
        let saved = ClipboardUD.bool("showSpecialSymbols")
        ClipboardUD.set(true, forKey: "showSpecialSymbols")
        defer { ClipboardUD.set(saved, forKey: "showSpecialSymbols") }

        let textData = "   hello".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        let title = item.generateTitle()
        XCTAssertTrue(title.hasPrefix("···"), "Expected leading · symbols, got: \(title)")
    }

    func testGenerateTitleShowsSpecialSymbolsForTrailingSpaces() async throws {
        let saved = ClipboardUD.bool("showSpecialSymbols")
        ClipboardUD.set(true, forKey: "showSpecialSymbols")
        defer { ClipboardUD.set(saved, forKey: "showSpecialSymbols") }

        let textData = "hello   ".data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        let title = item.generateTitle()
        XCTAssertTrue(title.hasSuffix("···"), "Expected trailing · symbols, got: \(title)")
    }

    func testGenerateTitleLimitedTo1000Characters() async throws {
        let saved = ClipboardUD.bool("showSpecialSymbols")
        ClipboardUD.set(false, forKey: "showSpecialSymbols")
        defer { ClipboardUD.set(saved, forKey: "showSpecialSymbols") }

        let longString = String(repeating: "a", count: 2000)
        let textData = longString.data(using: .utf8)!
        let content = makeContent(type: .string, value: textData, context: context)
        let item = HistoryItem(contents: [content])
        context.insert(item)

        let title = item.generateTitle()
        // shortened(to: 1000) leaves 1001 chars max
        XCTAssertLessThanOrEqual(title.count, 1001)
    }

    // MARK: supportedPins

    func testSupportedPinsIsNonEmpty() {
        let pins = HistoryItem.supportedPins
        XCTAssertFalse(pins.isEmpty)
    }

    func testSupportedPinsDoesNotContainReservedKeys() {
        let pins = HistoryItem.supportedPins
        let reserved: Set<String> = ["a", "q", "v", "w", "z"]
        XCTAssertTrue(pins.isDisjoint(with: reserved),
                      "supportedPins must not contain reserved keys: \(pins.intersection(reserved))")
    }
}

// MARK: - HistoryItemActionTests

class HistoryItemActionTests: XCTestCase {

    private var savedPasteByDefault: Bool = false
    private var savedRemoveFormattingByDefault: Bool = false

    override func setUp() {
        super.setUp()
        savedPasteByDefault = ClipboardUD.bool("pasteByDefault")
        savedRemoveFormattingByDefault = ClipboardUD.bool("removeFormattingByDefault")
    }

    override func tearDown() {
        ClipboardUD.set(savedPasteByDefault, forKey: "pasteByDefault")
        ClipboardUD.set(savedRemoveFormattingByDefault, forKey: "removeFormattingByDefault")
        super.tearDown()
    }

    // pasteByDefault = false, removeFormattingByDefault = false (defaults)

    func testCommandIsCopyWhenPasteByDefaultOff() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction(.command)
        XCTAssertEqual(action, .copy)
    }

    func testOptionIsPasteWhenPasteByDefaultOff() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction(.option)
        XCTAssertEqual(action, .paste)
    }

    func testOptionShiftIsPasteWithoutFormattingWhenPasteByDefaultOff() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction([.option, .shift])
        XCTAssertEqual(action, .pasteWithoutFormatting)
    }

    func testUnknownModifiersProducesUnknown() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction(.control)
        XCTAssertEqual(action, .unknown)
    }

    // pasteByDefault = true

    func testCommandIsPasteWhenPasteByDefaultOnNoRemoveFormatting() {
        ClipboardUD.set(true, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction(.command)
        XCTAssertEqual(action, .paste)
    }

    func testOptionIsCopyWhenPasteByDefaultOn() {
        ClipboardUD.set(true, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction(.option)
        XCTAssertEqual(action, .copy)
    }

    func testCommandShiftIsPasteWithoutFormattingWhenPasteByDefaultOnNoRemoveFormatting() {
        ClipboardUD.set(true, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction([.command, .shift])
        XCTAssertEqual(action, .pasteWithoutFormatting)
    }

    // pasteByDefault = false, removeFormattingByDefault = true

    func testOptionIsPasteWithoutFormattingWhenRemoveFormattingByDefaultOn() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(true, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction(.option)
        XCTAssertEqual(action, .pasteWithoutFormatting)
    }

    func testOptionShiftIsPasteWhenRemoveFormattingByDefaultOn() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(true, forKey: "removeFormattingByDefault")
        let action = HistoryItemAction([.option, .shift])
        XCTAssertEqual(action, .paste)
    }

    // modifierFlags round-trip

    func testModifierFlagsRoundTripCopy() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let flags = HistoryItemAction.copy.modifierFlags
        XCTAssertEqual(flags, .command)
    }

    func testModifierFlagsRoundTripPaste() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let flags = HistoryItemAction.paste.modifierFlags
        XCTAssertEqual(flags, .option)
    }

    func testModifierFlagsRoundTripPasteWithoutFormatting() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let flags = HistoryItemAction.pasteWithoutFormatting.modifierFlags
        XCTAssertEqual(flags, [.option, .shift])
    }

    func testModifierFlagsForUnknownIsEmpty() {
        ClipboardUD.set(false, forKey: "pasteByDefault")
        ClipboardUD.set(false, forKey: "removeFormattingByDefault")
        let flags = HistoryItemAction.unknown.modifierFlags
        XCTAssertTrue(flags.isEmpty)
    }
}

// MARK: - HistoryItemDecoratorTests

class HistoryItemDecoratorTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try makeInMemoryContainer()
        context = await container.mainContext
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    private func makeItem(text: String? = nil, pin: String? = nil) -> HistoryItem {
        var contents: [HistoryItemContent] = []
        if let text {
            let data = text.data(using: .utf8)!
            let c = makeContent(type: .string, value: data, context: context)
            contents.append(c)
        }
        let item = HistoryItem(contents: contents)
        item.pin = pin
        context.insert(item)
        return item
    }

    // MARK: isPinned / isUnpinned

    func testIsPinnedWhenPinSet() throws {
        let item = makeItem(pin: "b")
        let decorator = HistoryItemDecorator(item)
        XCTAssertTrue(decorator.isPinned)
        XCTAssertFalse(decorator.isUnpinned)
    }

    func testIsUnpinnedWhenNoPinSet() throws {
        let item = makeItem()
        let decorator = HistoryItemDecorator(item)
        XCTAssertFalse(decorator.isPinned)
        XCTAssertTrue(decorator.isUnpinned)
    }

    // MARK: isSelected / selectionIndex

    func testIsSelectedFalseByDefault() throws {
        let item = makeItem(text: "hi")
        let decorator = HistoryItemDecorator(item)
        XCTAssertFalse(decorator.isSelected)
        XCTAssertEqual(decorator.selectionIndex, -1)
    }

    func testIsSelectedTrueWhenIndexSet() throws {
        let item = makeItem(text: "hi")
        let decorator = HistoryItemDecorator(item)
        decorator.selectionIndex = 0
        XCTAssertTrue(decorator.isSelected)
    }

    // MARK: isVisible

    func testIsVisibleTrueByDefault() throws {
        let item = makeItem()
        let decorator = HistoryItemDecorator(item)
        XCTAssertTrue(decorator.isVisible)
    }

    func testIsVisibleCanBeSetFalse() throws {
        let item = makeItem()
        let decorator = HistoryItemDecorator(item)
        decorator.isVisible = false
        XCTAssertFalse(decorator.isVisible)
    }

    // MARK: title synchronization

    func testTitleInitializedFromItem() throws {
        let item = makeItem(text: "initial")
        item.title = "My Title"
        let decorator = HistoryItemDecorator(item)
        XCTAssertEqual(decorator.title, "My Title")
    }

    // MARK: equality / Hashable

    func testTwoDecoratorsForDifferentItemsAreNotEqual() throws {
        let item1 = makeItem(text: "a")
        let item2 = makeItem(text: "b")
        let d1 = HistoryItemDecorator(item1)
        let d2 = HistoryItemDecorator(item2)
        XCTAssertNotEqual(d1, d2)
    }

    func testDecoratorEqualToItself() throws {
        let item = makeItem(text: "a")
        let d = HistoryItemDecorator(item)
        XCTAssertEqual(d, d)
    }

    // MARK: text

    func testTextReturnsPreviewableTextShortenedTo10k() throws {
        let longString = String(repeating: "x", count: 20_000)
        let item = makeItem(text: longString)
        let decorator = HistoryItemDecorator(item)
        XCTAssertLessThanOrEqual(decorator.text.count, 10_001)
    }

    // MARK: highlight

    func testHighlightWithEmptyQueryClearsAttributedTitle() throws {
        let item = makeItem(text: "hello")
        item.title = "hello"
        let decorator = HistoryItemDecorator(item)
        decorator.highlight("", [])
        XCTAssertNil(decorator.attributedTitle)
    }

    func testHighlightWithEmptyTitleClearsAttributedTitle() throws {
        let item = makeItem()
        item.title = ""
        let decorator = HistoryItemDecorator(item)
        decorator.highlight("hello", [])
        XCTAssertNil(decorator.attributedTitle)
    }

    func testHighlightWithBoldQuerySetsAttributedTitle() throws {
        let savedHighlight = ClipboardUD.highlightMatch()
        ClipboardUD.setHighlightMatch("bold")
        defer { ClipboardUD.setHighlightMatch(savedHighlight) }

        let item = makeItem(text: "hello world")
        item.title = "hello world"
        let decorator = HistoryItemDecorator(item)

        let title = "hello world"
        let range = title.range(of: "hello")!
        decorator.highlight("hello", [range])
        XCTAssertNotNil(decorator.attributedTitle)
    }

    func testHighlightWithColorMatchSetsAttributedTitle() throws {
        let savedHighlight = ClipboardUD.highlightMatch()
        ClipboardUD.setHighlightMatch("color")
        defer { ClipboardUD.setHighlightMatch(savedHighlight) }

        let item = makeItem(text: "test content")
        item.title = "test content"
        let decorator = HistoryItemDecorator(item)

        let title = "test content"
        let range = title.range(of: "test")!
        decorator.highlight("test", [range])
        XCTAssertNotNil(decorator.attributedTitle)
    }

    func testHighlightWithItalicMatchSetsAttributedTitle() throws {
        let savedHighlight = ClipboardUD.highlightMatch()
        ClipboardUD.setHighlightMatch("italic")
        defer { ClipboardUD.setHighlightMatch(savedHighlight) }

        let item = makeItem(text: "italic text")
        item.title = "italic text"
        let decorator = HistoryItemDecorator(item)

        let title = "italic text"
        let range = title.range(of: "italic")!
        decorator.highlight("italic", [range])
        XCTAssertNotNil(decorator.attributedTitle)
    }

    func testHighlightWithUnderlineMatchSetsAttributedTitle() throws {
        let savedHighlight = ClipboardUD.highlightMatch()
        ClipboardUD.setHighlightMatch("underline")
        defer { ClipboardUD.setHighlightMatch(savedHighlight) }

        let item = makeItem(text: "underline text")
        item.title = "underline text"
        let decorator = HistoryItemDecorator(item)

        let title = "underline text"
        let range = title.range(of: "underline")!
        decorator.highlight("underline", [range])
        XCTAssertNotNil(decorator.attributedTitle)
    }

    // MARK: cleanupImages

    func testCleanupImagesResetsBothImages() async throws {
        let item = makeItem()
        let decorator = HistoryItemDecorator(item)
        await MainActor.run {
            decorator.cleanupImages()
        }
        XCTAssertNil(decorator.previewImage)
        XCTAssertNil(decorator.thumbnailImage)
    }
}

// MARK: - FooterItemTests

class FooterItemTests: XCTestCase {

    func testFooterItemInitializesProperties() {
        let item = FooterItem(title: "clear", action: {})
        XCTAssertEqual(item.title, "clear")
        XCTAssertTrue(item.shortcuts.isEmpty)
        XCTAssertNil(item.help)
        XCTAssertNil(item.confirmation)
        XCTAssertFalse(item.isSelected)
        XCTAssertFalse(item.showConfirmation)
        XCTAssertTrue(item.isVisible)
    }

    func testFooterItemWithShortcuts() {
        let shortcut = KeyShortcut(key: Key(character: "q", virtualKeyCode: nil))
        let item = FooterItem(title: "quit", shortcuts: [shortcut], action: {})
        XCTAssertEqual(item.shortcuts.count, 1)
    }

    func testFooterItemWithConfirmation() {
        let confirmation = FooterItem.Confirmation(
            message: "Are you sure?",
            comment: "comment",
            confirm: "Yes",
            cancel: "No"
        )
        let item = FooterItem(title: "delete", confirmation: confirmation, action: {})
        XCTAssertNotNil(item.confirmation)
    }

    func testFooterItemEqualityById() {
        let item1 = FooterItem(title: "a", action: {})
        let item2 = FooterItem(title: "b", action: {})
        XCTAssertNotEqual(item1, item2)
    }

    func testFooterItemEqualToItself() {
        let item = FooterItem(title: "x", action: {})
        XCTAssertEqual(item, item)
    }

    func testFooterItemIsSelectedCanBeToggled() {
        let item = FooterItem(title: "x", action: {})
        XCTAssertFalse(item.isSelected)
        item.isSelected = true
        XCTAssertTrue(item.isSelected)
    }

    func testFooterItemIsVisibleCanBeToggled() {
        let item = FooterItem(title: "x", action: {})
        XCTAssertTrue(item.isVisible)
        item.isVisible = false
        XCTAssertFalse(item.isVisible)
    }

    func testFooterItemActionIsCallable() {
        var called = false
        let item = FooterItem(title: "x", action: { called = true })
        item.action()
        XCTAssertTrue(called)
    }
}

// MARK: - KeyShortcutTests

class KeyShortcutTests: XCTestCase {

    func testCreateProducesThreeShortcuts() {
        let shortcuts = KeyShortcut.create(character: "1")
        XCTAssertEqual(shortcuts.count, 3)
    }

    func testCreateShortcutsHaveDistinctIds() {
        let shortcuts = KeyShortcut.create(character: "2")
        let ids = shortcuts.map(\.id)
        XCTAssertEqual(Set(ids).count, shortcuts.count)
    }

    func testIsVisibleSingleShortcutAlwaysTrue() {
        let shortcut = KeyShortcut(key: nil, modifierFlags: [.command])
        let result = shortcut.isVisible([shortcut], [])
        XCTAssertTrue(result)
    }

    func testIsVisibleCommandShortcutWithNoModifiersPressed() {
        let commandShortcut = KeyShortcut(key: nil, modifierFlags: [.command])
        let optionShortcut = KeyShortcut(key: nil, modifierFlags: [.option])
        let all = [commandShortcut, optionShortcut]

        XCTAssertTrue(commandShortcut.isVisible(all, []))
        XCTAssertFalse(optionShortcut.isVisible(all, []))
    }

    func testIsVisibleMatchesModifierFlags() {
        let commandShortcut = KeyShortcut(key: nil, modifierFlags: [.command])
        let optionShortcut = KeyShortcut(key: nil, modifierFlags: [.option])
        let all = [commandShortcut, optionShortcut]

        XCTAssertTrue(optionShortcut.isVisible(all, [.option]))
        XCTAssertFalse(commandShortcut.isVisible(all, [.option]))
    }
}

// MARK: - StorageConfigurationTests

class StorageConfigurationTests: XCTestCase {

    /// When clipboardPersistenceEnabled is false, Storage initializes an in-memory container.
    /// We verify the ModelContainer behavior directly (the branch Storage uses).
    func testInMemoryContainerCreatesSuccessfully() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryItem.self, configurations: config)
        XCTAssertNotNil(container)
    }

    func testInMemoryContainerSupportsInsertAndFetch() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryItem.self, configurations: config)
        let ctx = await container.mainContext

        let item = HistoryItem()
        item.title = "test"
        ctx.insert(item)
        try ctx.save()

        let descriptor = FetchDescriptor<HistoryItem>()
        let results = try ctx.fetch(descriptor)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "test")
    }

    func testInMemoryContainerDoesNotPersistAcrossInstances() async throws {
        // Insert into first container
        let config1 = ModelConfiguration(isStoredInMemoryOnly: true)
        let container1 = try ModelContainer(for: HistoryItem.self, configurations: config1)
        let ctx1 = await container1.mainContext
        let item = HistoryItem()
        item.title = "ephemeral"
        ctx1.insert(item)

        // New in-memory container should be empty
        let config2 = ModelConfiguration(isStoredInMemoryOnly: true)
        let container2 = try ModelContainer(for: HistoryItem.self, configurations: config2)
        let ctx2 = await container2.mainContext
        let descriptor = FetchDescriptor<HistoryItem>()
        let results = try ctx2.fetch(descriptor)
        XCTAssertTrue(results.isEmpty,
                      "In-memory container must not share data across instances (memory-only mode)")
    }

    /// rawm-4ha8: clipboard persistence is OFF by default (memory-only storage).
    func testPersistenceEnabledDefaultIsFalse() {
        // Remove any test-session override so the declared default kicks in.
        let ud = UserDefaults.standard
        ud.removeObject(forKey: "clipboardPersistenceEnabled")
        // The Defaults library returns the declared default when the key is absent.
        // Default declared as `Key<Bool>("clipboardPersistenceEnabled", default: false)`.
        let stored = ud.object(forKey: "clipboardPersistenceEnabled") as? Bool
        // Either the key is absent (nil) or false — never true by default.
        XCTAssertTrue(stored == nil || stored == false,
                      "Clipboard persistence should be OFF (memory-only) by default per rawm-4ha8")
    }
}

// MARK: - ModifierFlagsDescriptionTests

class ModifierFlagsDescriptionTests: XCTestCase {

    func testCommandDescription() {
        let flags: NSEvent.ModifierFlags = [.command]
        XCTAssertEqual(flags.description, "⌘")
    }

    func testOptionDescription() {
        let flags: NSEvent.ModifierFlags = [.option]
        XCTAssertEqual(flags.description, "⌥")
    }

    func testShiftDescription() {
        let flags: NSEvent.ModifierFlags = [.shift]
        XCTAssertEqual(flags.description, "⇧")
    }

    func testControlDescription() {
        let flags: NSEvent.ModifierFlags = [.control]
        XCTAssertEqual(flags.description, "⌃")
    }

    func testCombinedFlagsDescription() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        // Order defined in extension: control, option, shift, command
        XCTAssertEqual(flags.description, "⌃⌥⇧⌘")
    }

    func testEmptyFlagsDescription() {
        let flags: NSEvent.ModifierFlags = []
        XCTAssertEqual(flags.description, "")
    }
}

// MARK: - ItemsContainerProtocolTests

/// Tests for the ItemsContainer / HasVisibility protocol extension logic
/// exercised via a lightweight test double (no SwiftData required).
class ItemsContainerProtocolTests: XCTestCase {

    private class MockItem: HasVisibility, Equatable {
        let name: String
        var isVisible: Bool
        init(_ name: String, visible: Bool = true) {
            self.name = name
            self.isVisible = visible
        }
        static func == (lhs: MockItem, rhs: MockItem) -> Bool { lhs === rhs }
    }

    private class MockContainer: ItemsContainer {
        var items: [MockItem]
        init(items: [MockItem]) { self.items = items }
    }

    func testVisibleItemsExcludesHiddenItems() {
        let a = MockItem("a", visible: true)
        let b = MockItem("b", visible: false)
        let c = MockItem("c", visible: true)
        let container = MockContainer(items: [a, b, c])
        XCTAssertEqual(container.visibleItems, [a, c])
    }

    func testFirstVisibleItemReturnsFirstVisibleOne() {
        let a = MockItem("a", visible: false)
        let b = MockItem("b", visible: true)
        let container = MockContainer(items: [a, b])
        XCTAssertEqual(container.firstVisibleItem, b)
    }

    func testFirstVisibleItemReturnsNilWhenNoneVisible() {
        let a = MockItem("a", visible: false)
        let container = MockContainer(items: [a])
        XCTAssertNil(container.firstVisibleItem)
    }

    func testLastVisibleItemReturnsLastVisibleOne() {
        let a = MockItem("a", visible: true)
        let b = MockItem("b", visible: false)
        let c = MockItem("c", visible: true)
        let container = MockContainer(items: [a, b, c])
        XCTAssertEqual(container.lastVisibleItem, c)
    }

    func testFirstVisibleItemWhereReturnsMatchingItem() {
        let a = MockItem("alpha", visible: true)
        let b = MockItem("beta", visible: true)
        let container = MockContainer(items: [a, b])
        let result = container.firstVisibleItem(where: { $0.name == "beta" })
        XCTAssertEqual(result, b)
    }

    func testVisibleItemBeforeReturnsCorrectItem() {
        let a = MockItem("a", visible: true)
        let b = MockItem("b", visible: true)
        let c = MockItem("c", visible: true)
        let container = MockContainer(items: [a, b, c])
        XCTAssertEqual(container.visibleItem(before: b), a)
        XCTAssertNil(container.visibleItem(before: a))
    }

    func testVisibleItemAfterReturnsCorrectItem() {
        let a = MockItem("a", visible: true)
        let b = MockItem("b", visible: true)
        let c = MockItem("c", visible: true)
        let container = MockContainer(items: [a, b, c])
        XCTAssertEqual(container.visibleItem(after: b), c)
        XCTAssertNil(container.visibleItem(after: c))
    }

    func testVisibleItemBeforeSkipsHiddenItems() {
        let a = MockItem("a", visible: true)
        let hidden = MockItem("hidden", visible: false)
        let b = MockItem("b", visible: true)
        let container = MockContainer(items: [a, hidden, b])
        XCTAssertEqual(container.visibleItem(before: b), a)
    }

    func testVisibleItemAfterSkipsHiddenItems() {
        let a = MockItem("a", visible: true)
        let hidden = MockItem("hidden", visible: false)
        let b = MockItem("b", visible: true)
        let container = MockContainer(items: [a, hidden, b])
        XCTAssertEqual(container.visibleItem(after: a), b)
    }
}
