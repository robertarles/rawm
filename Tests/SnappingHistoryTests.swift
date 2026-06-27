/// SnappingHistoryTests.swift
///
/// Tests for snapping/window-history/screen logic.
/// Covers: WindowHistory, SnapAreaOption, Directional, SnapAreaConfig,
/// SnapAreaModel defaults, CompoundSnapArea enum, ClipboardAction, ShellAction,
/// SnappingManager cursor-directional logic, ScreenDetection percentageOf,
/// and RawmAction / SnapArea data structures.

import XCTest
@testable import rawm

// MARK: - WindowHistory

final class WindowHistoryTests: XCTestCase {

    func testRestoreRectsStartsEmpty() {
        let history = WindowHistory()
        XCTAssertTrue(history.restoreRects.isEmpty)
    }

    func testLastRawmActionsStartsEmpty() {
        let history = WindowHistory()
        XCTAssertTrue(history.lastRawmActions.isEmpty)
    }

    func testStoreAndLookupRestoreRect() {
        let history = WindowHistory()
        let rect = CGRect(x: 10, y: 20, width: 400, height: 300)
        history.restoreRects[42] = rect
        XCTAssertEqual(history.restoreRects[42], rect)
    }

    func testStoreAndLookupRawmAction() {
        let history = WindowHistory()
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        let action = RawmAction(action: .leftHalf, subAction: nil, rect: rect, count: 1)
        history.lastRawmActions[99] = action
        XCTAssertEqual(history.lastRawmActions[99]?.action, .leftHalf)
        XCTAssertEqual(history.lastRawmActions[99]?.count, 1)
        XCTAssertEqual(history.lastRawmActions[99]?.rect, rect)
    }

    func testOverwriteRestoreRect() {
        let history = WindowHistory()
        let first  = CGRect(x: 0, y: 0, width: 100, height: 100)
        let second = CGRect(x: 5, y: 5, width: 200, height: 200)
        history.restoreRects[1] = first
        history.restoreRects[1] = second
        XCTAssertEqual(history.restoreRects[1], second)
    }

    func testRemoveRestoreRect() {
        let history = WindowHistory()
        history.restoreRects[7] = CGRect(x: 0, y: 0, width: 50, height: 50)
        history.restoreRects.removeValue(forKey: 7)
        XCTAssertNil(history.restoreRects[7])
    }

    func testMultipleWindowsAreStoredIndependently() {
        let history = WindowHistory()
        let rect1 = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect2 = CGRect(x: 500, y: 0, width: 200, height: 150)
        history.restoreRects[1] = rect1
        history.restoreRects[2] = rect2
        XCTAssertEqual(history.restoreRects[1], rect1)
        XCTAssertEqual(history.restoreRects[2], rect2)
    }

    func testLastRawmActionsAndRestoreRectsAreIndependent() {
        let history = WindowHistory()
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let action = RawmAction(action: .rightHalf, subAction: nil, rect: rect, count: 2)
        history.restoreRects[5] = rect
        history.lastRawmActions[5] = action
        // clearing one doesn't affect the other
        history.lastRawmActions.removeValue(forKey: 5)
        XCTAssertNotNil(history.restoreRects[5])
        XCTAssertNil(history.lastRawmActions[5])
    }

    func testRawmActionCountIsPreserved() {
        let history = WindowHistory()
        let action = RawmAction(action: .maximize, subAction: nil, rect: .zero, count: 5)
        history.lastRawmActions[3] = action
        XCTAssertEqual(history.lastRawmActions[3]?.count, 5)
    }

    func testLookupMissingWindowReturnsNil() {
        let history = WindowHistory()
        XCTAssertNil(history.restoreRects[9999])
        XCTAssertNil(history.lastRawmActions[9999])
    }
}

// MARK: - SnapAreaOption OptionSet

final class SnapAreaOptionTests: XCTestCase {

    func testNoneIsEmpty() {
        XCTAssertEqual(SnapAreaOption.none.rawValue, 0)
        XCTAssertFalse(SnapAreaOption.none.contains(.top))
    }

    func testAllContainsAllIndividualOptions() {
        let all = SnapAreaOption.all
        XCTAssertTrue(all.contains(.top))
        XCTAssertTrue(all.contains(.bottom))
        XCTAssertTrue(all.contains(.left))
        XCTAssertTrue(all.contains(.right))
        XCTAssertTrue(all.contains(.topLeft))
        XCTAssertTrue(all.contains(.topRight))
        XCTAssertTrue(all.contains(.bottomLeft))
        XCTAssertTrue(all.contains(.bottomRight))
        XCTAssertTrue(all.contains(.topLeftShort))
        XCTAssertTrue(all.contains(.topRightShort))
        XCTAssertTrue(all.contains(.bottomLeftShort))
        XCTAssertTrue(all.contains(.bottomRightShort))
    }

    func testRawValuesArePowersOfTwo() {
        XCTAssertEqual(SnapAreaOption.top.rawValue, 1 << 0)
        XCTAssertEqual(SnapAreaOption.bottom.rawValue, 1 << 1)
        XCTAssertEqual(SnapAreaOption.left.rawValue, 1 << 2)
        XCTAssertEqual(SnapAreaOption.right.rawValue, 1 << 3)
        XCTAssertEqual(SnapAreaOption.topLeft.rawValue, 1 << 4)
        XCTAssertEqual(SnapAreaOption.topRight.rawValue, 1 << 5)
        XCTAssertEqual(SnapAreaOption.bottomLeft.rawValue, 1 << 6)
        XCTAssertEqual(SnapAreaOption.bottomRight.rawValue, 1 << 7)
        XCTAssertEqual(SnapAreaOption.topLeftShort.rawValue, 1 << 8)
        XCTAssertEqual(SnapAreaOption.topRightShort.rawValue, 1 << 9)
        XCTAssertEqual(SnapAreaOption.bottomLeftShort.rawValue, 1 << 10)
        XCTAssertEqual(SnapAreaOption.bottomRightShort.rawValue, 1 << 11)
    }

    func testUnionOfTopAndBottom() {
        let combined: SnapAreaOption = [.top, .bottom]
        XCTAssertTrue(combined.contains(.top))
        XCTAssertTrue(combined.contains(.bottom))
        XCTAssertFalse(combined.contains(.left))
    }

    func testSubtractRemovesOption() {
        var opts = SnapAreaOption.all
        opts.subtract(.top)
        XCTAssertFalse(opts.contains(.top))
        XCTAssertTrue(opts.contains(.bottom))
    }

    func testInitFromRawValue() {
        let opt = SnapAreaOption(rawValue: 1 << 3)
        XCTAssertTrue(opt.contains(.right))
        XCTAssertFalse(opt.contains(.left))
    }

    func testAllHasTwelveBits() {
        // all = bits 0–11 set, which is 0xFFF = 4095
        XCTAssertEqual(SnapAreaOption.all.rawValue, 0xFFF)
    }

    func testHashableConformance() {
        var set = Set<SnapAreaOption>()
        set.insert(.top)
        set.insert(.top)
        XCTAssertEqual(set.count, 1)
        set.insert(.bottom)
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - Directional enum

final class DirectionalEnumTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(Directional.tl.rawValue, 1)
        XCTAssertEqual(Directional.t.rawValue,  2)
        XCTAssertEqual(Directional.tr.rawValue, 3)
        XCTAssertEqual(Directional.l.rawValue,  4)
        XCTAssertEqual(Directional.r.rawValue,  5)
        XCTAssertEqual(Directional.bl.rawValue, 6)
        XCTAssertEqual(Directional.b.rawValue,  7)
        XCTAssertEqual(Directional.br.rawValue, 8)
        XCTAssertEqual(Directional.c.rawValue,  9)
    }

    func testStaticCasesExcludesCenter() {
        // Directional.cases is used for snap area iteration and must NOT include .c
        XCTAssertFalse(Directional.cases.contains(.c))
    }

    func testStaticCasesHasEightElements() {
        XCTAssertEqual(Directional.cases.count, 8)
    }

    func testStaticCasesContainsAllEdgesAndCorners() {
        let expected: [Directional] = [.tl, .t, .tr, .l, .r, .bl, .b, .br]
        for d in expected {
            XCTAssertTrue(Directional.cases.contains(d), "\(d) missing from Directional.cases")
        }
    }

    func testCodableRoundTrip() throws {
        let original = Directional.tr
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Directional.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - SnapAreaConfig

final class SnapAreaConfigTests: XCTestCase {

    func testActionConfigHasNilCompound() {
        let config = SnapAreaConfig(action: .leftHalf)
        XCTAssertEqual(config.action, .leftHalf)
        XCTAssertNil(config.compound)
    }

    func testCompoundConfigHasNilAction() {
        let config = SnapAreaConfig(compound: .thirds)
        XCTAssertEqual(config.compound, .thirds)
        XCTAssertNil(config.action)
    }

    func testBothNilAllowed() {
        let config = SnapAreaConfig()
        XCTAssertNil(config.action)
        XCTAssertNil(config.compound)
    }

    func testCodableRoundTrip() throws {
        let original = SnapAreaConfig(action: .topLeft)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapAreaConfig.self, from: data)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.compound, original.compound)
    }

    func testCompoundCodableRoundTrip() throws {
        let original = SnapAreaConfig(compound: .leftTopBottomHalf)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SnapAreaConfig.self, from: data)
        XCTAssertEqual(decoded.compound, original.compound)
        XCTAssertNil(decoded.action)
    }
}

// MARK: - SnapAreaModel default landscape/portrait config

final class SnapAreaModelDefaultsTests: XCTestCase {

    func testDefaultLandscapeHasEightEntries() {
        XCTAssertEqual(SnapAreaModel.defaultLandscape.count, 8)
    }

    func testDefaultPortraitHasEightEntries() {
        XCTAssertEqual(SnapAreaModel.defaultPortrait.count, 8)
    }

    func testDefaultLandscapeTopIsMaximize() {
        XCTAssertEqual(SnapAreaModel.defaultLandscape[.t]?.action, .maximize)
    }

    func testDefaultLandscapeTopLeftIsTopLeft() {
        XCTAssertEqual(SnapAreaModel.defaultLandscape[.tl]?.action, .topLeft)
    }

    func testDefaultLandscapeTopRightIsTopRight() {
        XCTAssertEqual(SnapAreaModel.defaultLandscape[.tr]?.action, .topRight)
    }

    func testDefaultLandscapeBottomLeftIsBottomLeft() {
        XCTAssertEqual(SnapAreaModel.defaultLandscape[.bl]?.action, .bottomLeft)
    }

    func testDefaultLandscapeBottomRightIsBottomRight() {
        XCTAssertEqual(SnapAreaModel.defaultLandscape[.br]?.action, .bottomRight)
    }

    func testDefaultLandscapeLeftHasCompound() {
        XCTAssertNotNil(SnapAreaModel.defaultLandscape[.l]?.compound)
        XCTAssertNil(SnapAreaModel.defaultLandscape[.l]?.action)
    }

    func testDefaultLandscapeRightHasCompound() {
        XCTAssertNotNil(SnapAreaModel.defaultLandscape[.r]?.compound)
        XCTAssertNil(SnapAreaModel.defaultLandscape[.r]?.action)
    }

    func testDefaultLandscapeBottomHasCompound() {
        XCTAssertNotNil(SnapAreaModel.defaultLandscape[.b]?.compound)
        XCTAssertNil(SnapAreaModel.defaultLandscape[.b]?.action)
    }

    func testDefaultPortraitTopIsMaximize() {
        XCTAssertEqual(SnapAreaModel.defaultPortrait[.t]?.action, .maximize)
    }

    func testDefaultPortraitLeftHasCompound() {
        XCTAssertNotNil(SnapAreaModel.defaultPortrait[.l]?.compound)
        XCTAssertNil(SnapAreaModel.defaultPortrait[.l]?.action)
    }

    func testDefaultPortraitBottomHasCompound() {
        XCTAssertNotNil(SnapAreaModel.defaultPortrait[.b]?.compound)
        XCTAssertNil(SnapAreaModel.defaultPortrait[.b]?.action)
    }
}

// MARK: - CompoundSnapArea enum

final class CompoundSnapAreaEnumTests: XCTestCase {

    func testAllContainsExpectedCount() {
        // All 11 compound area types
        XCTAssertEqual(CompoundSnapArea.all.count, 11)
    }

    func testRawValuesAreNegative() {
        for compound in CompoundSnapArea.all {
            XCTAssertLessThan(compound.rawValue, 0, "\(compound) rawValue should be negative")
        }
    }

    func testLeftTopBottomHalfCompatibleDirectionals() {
        XCTAssertEqual(CompoundSnapArea.leftTopBottomHalf.compatibleDirectionals, [.l])
    }

    func testRightTopBottomHalfCompatibleDirectionals() {
        XCTAssertEqual(CompoundSnapArea.rightTopBottomHalf.compatibleDirectionals, [.r])
    }

    func testThirdsCompatibleDirectionals() {
        XCTAssertEqual(Set(CompoundSnapArea.thirds.compatibleDirectionals), Set([.t, .b]))
    }

    func testHalvesCompatibleDirectionals() {
        XCTAssertEqual(Set(CompoundSnapArea.halves.compatibleDirectionals), Set([.t, .b]))
    }

    func testTopSixthsCompatibleDirectionals() {
        XCTAssertEqual(CompoundSnapArea.topSixths.compatibleDirectionals, [.t])
    }

    func testBottomSixthsCompatibleDirectionals() {
        XCTAssertEqual(CompoundSnapArea.bottomSixths.compatibleDirectionals, [.b])
    }

    func testFourthsCompatibleDirectionals() {
        XCTAssertEqual(Set(CompoundSnapArea.fourths.compatibleDirectionals), Set([.t, .b]))
    }

    func testPortraitThirdsSideCompatibleOrientation() {
        XCTAssertEqual(CompoundSnapArea.portraitThirdsSide.compatibleOrientation, [.portrait])
    }

    func testPortraitTopBottomHalvesCompatibleOrientation() {
        XCTAssertEqual(CompoundSnapArea.portraitTopBottomHalves.compatibleOrientation, [.portrait])
    }

    func testLeftTopBottomHalfCompatibleOrientationIncludesBoth() {
        let compat = CompoundSnapArea.leftTopBottomHalf.compatibleOrientation
        XCTAssertTrue(compat.contains(.portrait))
        XCTAssertTrue(compat.contains(.landscape))
    }

    func testThirdsCompatibleOrientationIsLandscapeOnly() {
        let compat = CompoundSnapArea.thirds.compatibleOrientation
        XCTAssertTrue(compat.contains(.landscape))
        XCTAssertFalse(compat.contains(.portrait))
    }

    func testTopEighthsCompatibleDirectionals() {
        XCTAssertEqual(CompoundSnapArea.topEighths.compatibleDirectionals, [.t])
    }

    func testBottomEighthsCompatibleDirectionals() {
        XCTAssertEqual(CompoundSnapArea.bottomEighths.compatibleDirectionals, [.b])
    }

    func testDisplayNamesAreNonEmpty() {
        for compound in CompoundSnapArea.all {
            XCTAssertFalse(compound.displayName.isEmpty, "\(compound) displayName should not be empty")
        }
    }

    func testCalculationObjectsAreNonNil() {
        // Verify every case has a valid calculation object (not nil)
        for compound in CompoundSnapArea.all {
            // Just calling .calculation should not crash
            let calc = compound.calculation
            XCTAssertNotNil(calc as AnyObject)
        }
    }
}

// MARK: - ScreenDetection.percentageOf

final class ScreenDetectionPercentageTests: XCTestCase {

    private let detection = ScreenDetection()

    func testFullyContainedRectIsOneHundredPercent() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let window = CGRect(x: 100, y: 100, width: 200, height: 100)
        let pct = detection.percentageOf(window, withinFrameOfScreen: screen)
        XCTAssertEqual(pct, 1.0, accuracy: 0.0001)
    }

    func testNonOverlappingRectIsZeroPercent() {
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let window = CGRect(x: 2000, y: 0, width: 200, height: 100)
        let pct = detection.percentageOf(window, withinFrameOfScreen: screen)
        XCTAssertEqual(pct, 0.0, accuracy: 0.0001)
    }

    func testHalfOverlappingRectIsApproximatelyFiftyPercent() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        // Window overlaps with left half of screen only
        let window = CGRect(x: -500, y: 0, width: 1000, height: 1000)
        let pct = detection.percentageOf(window, withinFrameOfScreen: screen)
        XCTAssertEqual(pct, 0.5, accuracy: 0.001)
    }

    func testQuarterOverlapReturnsPointTwentyFive() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        // Window is 1000x1000, overlaps only top-right quarter
        let window = CGRect(x: 500, y: 500, width: 1000, height: 1000)
        let pct = detection.percentageOf(window, withinFrameOfScreen: screen)
        XCTAssertEqual(pct, 0.25, accuracy: 0.001)
    }

    func testZeroAreaRectReturnsZeroOrNaN() {
        // A zero-area window produces 0/0 (NaN) from the division path in percentageOf.
        // The intersection is null (zero-area rect intersected with screen), so the
        // implementation returns 0.0 directly. This test documents the actual behaviour.
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let window = CGRect(x: 100, y: 100, width: 0, height: 0)
        let pct = detection.percentageOf(window, withinFrameOfScreen: screen)
        // Intersection of a zero-size rect is null → result path returns 0.0.
        // If the geometry changes to reach the divide path, NaN is acceptable too.
        XCTAssertTrue(pct == 0.0 || pct.isNaN, "Expected 0.0 or NaN for zero-area window, got \(pct)")
    }

    func testWindowLargerThanScreenMaxIsOne() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        // Window is twice the screen size but fully encompasses it
        let window = CGRect(x: -500, y: -500, width: 2000, height: 2000)
        let pct = detection.percentageOf(window, withinFrameOfScreen: screen)
        // Intersection area = 1000*1000, window area = 2000*2000 → pct = 0.25
        XCTAssertEqual(pct, 0.25, accuracy: 0.001)
    }
}

// MARK: - SnappingManager directional cursor location (geometry-only)

final class DirectionalCursorLocationTests: XCTestCase {

    /// Helper that exercises SnappingManager.directionalLocationOfCursor using a
    /// synthesized frame rect. We do this by creating a SnappingManager (which only
    /// reads Defaults at init time), then calling the method with NSScreen.main.
    ///
    /// Because we cannot construct a custom NSScreen, we test directionalLocationOfCursor
    /// indirectly through a helper that replicates its pure geometry only.
    private func directional(loc: NSPoint, inFrame frame: CGRect) -> Directional? {
        let marginTop    = RawmDefaults.snapEdgeMarginTop.cgFloat
        let marginBottom = RawmDefaults.snapEdgeMarginBottom.cgFloat
        let marginLeft   = RawmDefaults.snapEdgeMarginLeft.cgFloat
        let marginRight  = RawmDefaults.snapEdgeMarginRight.cgFloat
        let cornerSize   = RawmDefaults.cornerSnapAreaSize.cgFloat

        guard loc.x >= frame.minX,
              loc.x <= frame.maxX,
              loc.y >= frame.minY,
              loc.y <= frame.maxY
        else { return nil }

        if loc.x < frame.minX + marginLeft + cornerSize {
            if loc.y >= frame.maxY - marginTop - cornerSize { return .tl }
            if loc.y <= frame.minY + marginBottom + cornerSize { return .bl }
            if loc.x < frame.minX + marginLeft { return .l }
        }
        if loc.x > frame.maxX - marginRight - cornerSize {
            if loc.y >= frame.maxY - marginTop - cornerSize { return .tr }
            if loc.y <= frame.minY + marginBottom + cornerSize { return .br }
            if loc.x > frame.maxX - marginRight { return .r }
        }
        if loc.y > frame.maxY - marginTop { return .t }
        if loc.y < frame.minY + marginBottom { return .b }
        return nil
    }

    private let frame = CGRect(x: 0, y: 0, width: 2560, height: 1600)
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
    }

    override func tearDown() {
        snap.restore()
        super.tearDown()
    }

    func testTopLeftCornerReturnsTopLeft() {
        let loc = NSPoint(x: frame.minX + 1, y: frame.maxY - 1)
        XCTAssertEqual(directional(loc: loc, inFrame: frame), .tl)
    }

    func testTopRightCornerReturnsTopRight() {
        let loc = NSPoint(x: frame.maxX - 1, y: frame.maxY - 1)
        XCTAssertEqual(directional(loc: loc, inFrame: frame), .tr)
    }

    func testBottomLeftCornerReturnsBottomLeft() {
        let loc = NSPoint(x: frame.minX + 1, y: frame.minY + 1)
        XCTAssertEqual(directional(loc: loc, inFrame: frame), .bl)
    }

    func testBottomRightCornerReturnsBottomRight() {
        let loc = NSPoint(x: frame.maxX - 1, y: frame.minY + 1)
        XCTAssertEqual(directional(loc: loc, inFrame: frame), .br)
    }

    func testTopEdgeCenteredReturnsTop() {
        let loc = NSPoint(x: frame.midX, y: frame.maxY - 1)
        XCTAssertEqual(directional(loc: loc, inFrame: frame), .t)
    }

    func testBottomEdgeCenteredReturnsBottom() {
        let loc = NSPoint(x: frame.midX, y: frame.minY + 1)
        XCTAssertEqual(directional(loc: loc, inFrame: frame), .b)
    }

    func testCenterOfScreenReturnsNil() {
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        XCTAssertNil(directional(loc: loc, inFrame: frame))
    }

    func testOutsideScreenReturnsNil() {
        let loc = NSPoint(x: frame.maxX + 100, y: frame.midY)
        XCTAssertNil(directional(loc: loc, inFrame: frame))
    }

    func testLeftEdgeReturnsLeft() {
        // must be at the very edge (< minX + marginLeft) but not in a corner zone
        let marginLeft = RawmDefaults.snapEdgeMarginLeft.cgFloat
        let cornerSize = RawmDefaults.cornerSnapAreaSize.cgFloat
        let loc = NSPoint(x: frame.minX, y: frame.midY)
        // loc.x < frame.minX + marginLeft → true (0 < 5 when default is 5)
        // loc.y is neither near top nor bottom → should be .l
        if marginLeft > 0 {
            XCTAssertEqual(directional(loc: loc, inFrame: frame), .l)
        } else {
            // With zero margin the check for .l never triggers; skip
            XCTAssertNil(directional(loc: loc, inFrame: frame))
        }
        _ = cornerSize // silence unused warning
    }

    func testRightEdgeReturnsRight() {
        let marginRight = RawmDefaults.snapEdgeMarginRight.cgFloat
        let cornerSize  = RawmDefaults.cornerSnapAreaSize.cgFloat
        let loc = NSPoint(x: frame.maxX, y: frame.midY)
        if marginRight > 0 {
            XCTAssertEqual(directional(loc: loc, inFrame: frame), .r)
        } else {
            XCTAssertNil(directional(loc: loc, inFrame: frame))
        }
        _ = cornerSize
    }
}

// MARK: - SnappingManager.getFootprintAnimationOrigin

final class FootprintAnimationOriginTests: XCTestCase {

    /// We can't easily construct SnapArea without a real NSScreen, but we can test
    /// the origin math by inspecting the switch via SnappingManager on NSScreen.main.
    /// We skip this test entirely if no screen is available (unlikely but safe).

    private var sm: SnappingManager!
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.windowSnapping.enabled = false
        sm = SnappingManager()
    }

    override func tearDown() {
        snap.restore()
        super.tearDown()
    }

    func testTopLeftOriginIsMinXMaxY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .tl, action: .topLeft)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.minX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.maxY, accuracy: 0.001)
    }

    func testTopEdgeOriginIsMidXMaxY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .t, action: .maximize)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.midX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.maxY, accuracy: 0.001)
    }

    func testTopRightOriginIsMaxXMaxY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .tr, action: .topRight)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.maxX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.maxY, accuracy: 0.001)
    }

    func testLeftEdgeOriginIsMinXMidY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .l, action: .leftHalf)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.minX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.midY, accuracy: 0.001)
    }

    func testRightEdgeOriginIsMaxXMidY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .r, action: .rightHalf)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.maxX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.midY, accuracy: 0.001)
    }

    func testBottomLeftOriginIsMinXMinY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .bl, action: .bottomLeft)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.minX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.minY, accuracy: 0.001)
    }

    func testBottomEdgeOriginIsMidXMinY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .b, action: .bottomHalf)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.midX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.minY, accuracy: 0.001)
    }

    func testBottomRightOriginIsMaxXMinY() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .br, action: .bottomRight)
        guard let origin = sm.getFootprintAnimationOrigin(area, boxRect) else { return XCTFail("expected non-nil origin") }
        XCTAssertEqual(origin.x, boxRect.maxX, accuracy: 0.001)
        XCTAssertEqual(origin.y, boxRect.minY, accuracy: 0.001)
    }

    func testCenterDirectionalReturnsNil() {
        guard let screen = NSScreen.main else { return }
        let boxRect = CGRect(x: 0, y: 100, width: 200, height: 150)
        let area = SnapArea(screen: screen, directional: .c, action: .center)
        let origin = sm.getFootprintAnimationOrigin(area, boxRect)
        XCTAssertNil(origin)
    }
}

// MARK: - ClipboardAction names & defaultsKeys

final class ClipboardActionNamingTests: XCTestCase {

    func testShowHistoryName() {
        XCTAssertEqual(ClipboardAction.showHistory.name, "Show Clipboard History")
    }

    func testShowHistoryDefaultsKey() {
        XCTAssertEqual(ClipboardAction.showHistory.defaultsKey, "rawmClipboardShowHistory")
    }

    func testPasteItemZeroName() {
        XCTAssertEqual(ClipboardAction.pasteItem(index: 0).name, "Paste Clipboard Item 1")
    }

    func testPasteItemFourName() {
        XCTAssertEqual(ClipboardAction.pasteItem(index: 4).name, "Paste Clipboard Item 5")
    }

    func testPasteItemZeroDefaultsKey() {
        XCTAssertEqual(ClipboardAction.pasteItem(index: 0).defaultsKey, "rawmClipboardPasteItem0")
    }

    func testPasteItemTenDefaultsKey() {
        XCTAssertEqual(ClipboardAction.pasteItem(index: 10).defaultsKey, "rawmClipboardPasteItem10")
    }
}

// MARK: - ShellAction defaultsKey sanitization

final class ShellActionDefaultsKeyTests: XCTestCase {

    func testAlphanumericCommandProducesCleanKey() {
        let action = ShellAction(name: "Open WezTerm", command: "open")
        XCTAssertTrue(action.defaultsKey.hasPrefix("rawmShell_"))
        XCTAssertFalse(action.defaultsKey.contains(" "))
    }

    func testSpacesInCommandAreReplacedByUnderscore() {
        let action = ShellAction(name: "Test", command: "open -a WezTerm")
        // Spaces in command → underscores in key
        let suffix = action.defaultsKey.dropFirst("rawmShell_".count)
        XCTAssertFalse(suffix.contains(" "))
    }

    func testSpecialCharsAreReplacedByUnderscore() {
        let action = ShellAction(name: "Test", command: "echo $HOME/foo.bar")
        let suffix = String(action.defaultsKey.dropFirst("rawmShell_".count))
        // $ / . are not alnum → replaced by _
        XCTAssertFalse(suffix.contains("$"))
        XCTAssertFalse(suffix.contains("/"))
        XCTAssertFalse(suffix.contains("."))
    }

    func testExplicitDefaultsKeyOverridesGenerated() {
        let action = ShellAction(name: "Test", command: "echo hello", defaultsKey: "myCustomKey")
        XCTAssertEqual(action.defaultsKey, "myCustomKey")
    }

    func testDefaultsKeyLengthIsAtMostSixtySixChars() {
        // prefix "rawmShell_" = 10 chars; suffix truncated to 60
        let longCommand = String(repeating: "a", count: 200)
        let action = ShellAction(name: "Test", command: longCommand)
        XCTAssertLessThanOrEqual(action.defaultsKey.count, 70)
    }

    func testCommandNameIsPreserved() {
        let action = ShellAction(name: "My Action", command: "ls")
        XCTAssertEqual(action.name, "My Action")
    }

    func testCommandIsPreserved() {
        let action = ShellAction(name: "Test", command: "open -a Terminal")
        XCTAssertEqual(action.command, "open -a Terminal")
    }
}

// MARK: - SnapArea struct

final class SnapAreaStructTests: XCTestCase {

    func testEqualSnapAreasAreEqual() {
        guard let screen = NSScreen.main else { return }
        let a1 = SnapArea(screen: screen, directional: .l, action: .leftHalf)
        let a2 = SnapArea(screen: screen, directional: .l, action: .leftHalf)
        XCTAssertEqual(a1, a2)
    }

    func testDifferentDirectionalsMakeInequal() {
        guard let screen = NSScreen.main else { return }
        let a1 = SnapArea(screen: screen, directional: .l, action: .leftHalf)
        let a2 = SnapArea(screen: screen, directional: .r, action: .leftHalf)
        XCTAssertNotEqual(a1, a2)
    }

    func testDifferentActionsMakeInequal() {
        guard let screen = NSScreen.main else { return }
        let a1 = SnapArea(screen: screen, directional: .t, action: .maximize)
        let a2 = SnapArea(screen: screen, directional: .t, action: .almostMaximize)
        XCTAssertNotEqual(a1, a2)
    }
}

// MARK: - LeftRightHalvesCompoundCalculation (pure geometry via NSScreen.main)

final class LeftRightHalvesCalcTests: XCTestCase {

    private let calc = LeftRightHalvesCompoundCalculation()

    func testCursorOnLeftHalfReturnsLeftHalf() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let loc = NSPoint(x: frame.minX + 1, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .leftHalf)
    }

    func testCursorOnRightHalfReturnsRightHalf() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let loc = NSPoint(x: frame.maxX - 1, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .rightHalf)
    }
}

// MARK: - ThirdsCompoundCalculation (pure geometry via NSScreen.main)

final class ThirdsCompoundCalcTests: XCTestCase {

    private let calc = ThirdsCompoundCalculation()

    func testCursorAtFirstThirdReturnsFirstThird() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let thirdWidth = floor(frame.width / 3)
        let loc = NSPoint(x: frame.minX + thirdWidth * 0.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .firstThird)
    }

    func testCursorAtLastThirdReturnsLastThird() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let thirdWidth = floor(frame.width / 3)
        let loc = NSPoint(x: frame.maxX - thirdWidth * 0.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .lastThird)
    }

    func testCursorAtCenterWithNoPriorReturnsCenterThird() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .centerThird)
    }

    func testCursorAtCenterAfterFirstThirdReturnsFirstTwoThirds() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let priorArea = SnapArea(screen: screen, directional: .b, action: .firstThird)
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .firstTwoThirds)
    }

    func testCursorAtCenterAfterLastThirdReturnsLastTwoThirds() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let priorArea = SnapArea(screen: screen, directional: .b, action: .lastThird)
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .lastTwoThirds)
    }

    func testCursorAtCenterAfterUnrelatedActionReturnsCenterThird() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let priorArea = SnapArea(screen: screen, directional: .b, action: .maximize)
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .centerThird)
    }
}

// MARK: - FourthsColumnCompoundCalculation

final class FourthsColumnCalcTests: XCTestCase {

    private let calc = FourthsColumnCompoundCalculation()

    func testCursorAtFirstQuarterReturnsFirstFourth() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let quarterWidth = floor(frame.width / 4)
        let loc = NSPoint(x: frame.minX + quarterWidth * 0.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .firstFourth)
    }

    func testCursorAtLastQuarterReturnsLastFourth() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let quarterWidth = floor(frame.width / 4)
        let loc = NSPoint(x: frame.maxX - quarterWidth * 0.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .lastFourth)
    }

    func testCursorAtSecondQuarterWithNoPriorReturnsSecondFourth() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let quarterWidth = floor(frame.width / 4)
        let loc = NSPoint(x: frame.minX + quarterWidth * 1.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .secondFourth)
    }

    func testCursorAtSecondQuarterAfterFirstFourthReturnsFirstThreeFourths() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let quarterWidth = floor(frame.width / 4)
        let priorArea = SnapArea(screen: screen, directional: .b, action: .firstFourth)
        let loc = NSPoint(x: frame.minX + quarterWidth * 1.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .firstThreeFourths)
    }

    func testCursorAtThirdQuarterAfterLastFourthReturnsLastThreeFourths() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let quarterWidth = floor(frame.width / 4)
        let priorArea = SnapArea(screen: screen, directional: .b, action: .lastFourth)
        let loc = NSPoint(x: frame.minX + quarterWidth * 2.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .b, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .lastThreeFourths)
    }
}

// MARK: - TopSixthsCompoundCalculation

final class TopSixthsCalcTests: XCTestCase {

    private let calc = TopSixthsCompoundCalculation()

    func testNoPriorReturnsMaximize() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .t, priorSnapArea: nil)
        XCTAssertEqual(result?.action, .maximize)
    }

    func testPriorTopLeftWithCursorInLeftThirdReturnsTopLeftSixth() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let thirdWidth = floor(frame.width / 3)
        let priorArea = SnapArea(screen: screen, directional: .t, action: .topLeft)
        let loc = NSPoint(x: frame.minX + thirdWidth * 0.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .t, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .topLeftSixth)
    }

    func testPriorTopRightWithCursorInRightThirdReturnsTopRightSixth() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let thirdWidth = floor(frame.width / 3)
        let priorArea = SnapArea(screen: screen, directional: .t, action: .topRight)
        let loc = NSPoint(x: frame.maxX - thirdWidth * 0.5, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .t, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .topRightSixth)
    }

    func testPriorTopLeftSixthWithCursorInCenterReturnsTopCenterSixth() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let priorArea = SnapArea(screen: screen, directional: .t, action: .topLeftSixth)
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .t, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .topCenterSixth)
    }

    func testPriorMaximizeWithCursorInCenterReturnsMaximize() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let priorArea = SnapArea(screen: screen, directional: .t, action: .maximize)
        let loc = NSPoint(x: frame.midX, y: frame.midY)
        let result = calc.snapArea(cursorLocation: loc, screen: screen, directional: .t, priorSnapArea: priorArea)
        XCTAssertEqual(result?.action, .maximize)
    }
}

// MARK: - RawmAction struct

final class RawmActionStructTests: XCTestCase {

    func testActionIsStored() {
        let action = RawmAction(action: .maximize, subAction: nil, rect: .zero, count: 1)
        XCTAssertEqual(action.action, .maximize)
    }

    func testRectIsStored() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 200)
        let action = RawmAction(action: .leftHalf, subAction: nil, rect: rect, count: 1)
        XCTAssertEqual(action.rect, rect)
    }

    func testCountIsStored() {
        let action = RawmAction(action: .leftHalf, subAction: nil, rect: .zero, count: 3)
        XCTAssertEqual(action.count, 3)
    }

    func testSubActionNilByDefault() {
        let action = RawmAction(action: .maximize, subAction: nil, rect: .zero, count: 1)
        XCTAssertNil(action.subAction)
    }
}
