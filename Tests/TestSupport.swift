/// TestSupport.swift
///
/// Shared fixtures and assertions for the rawm test suite. Keep this dependency-free
/// (no per-module knowledge) so every test file can rely on it.
///
/// Conventions:
///   - WindowCalculation tests are pure: build params with `rectParams(...)` /
///     `repeatedRectParams(...)` and assert the returned `.rect` with `assertRectsEqual`.
///   - Tests that mutate global RawmDefaults must snapshot/restore via
///     `RawmDefaultsSnapshot` (capture in setUp, `.restore()` in tearDown) so state
///     does not leak between tests.

import Cocoa
import XCTest
@testable import rawm

/// Common screen visible-frame fixtures (AppKit bottom-left origin coordinates).
enum TestScreens {
    /// The frame used by the legacy corner/half tests — keeps those numbers stable.
    static let standard = CGRect(x: 10, y: 20, width: 1200, height: 900)
    static let fullHD   = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    static let retina   = CGRect(x: 0, y: 0, width: 1440, height: 900)
    static let tiny     = CGRect(x: 0, y: 0, width: 100, height: 100)
    /// A secondary display to the left of the primary (negative origin).
    static let negativeOrigin = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
}

/// Build rect-calculation parameters for a single (non-repeated) action.
func rectParams(_ action: WindowAction,
                visibleFrame: CGRect = TestScreens.standard,
                windowRect: CGRect? = nil,
                lastAction: RawmAction? = nil) -> RectCalculationParameters {
    RectCalculationParameters(window: Window(id: 1, rect: windowRect ?? visibleFrame),
                              visibleFrameOfScreen: visibleFrame,
                              action: action,
                              lastAction: lastAction)
}

/// Build rect-calculation parameters that look like a *repeated* invocation of the
/// same action (used to exercise cycling behavior).
func repeatedRectParams(_ action: WindowAction,
                        visibleFrame: CGRect = TestScreens.standard,
                        currentRect: CGRect? = nil,
                        count: Int = 1) -> RectCalculationParameters {
    let rect = currentRect ?? visibleFrame
    return RectCalculationParameters(window: Window(id: 1, rect: rect),
                                     visibleFrameOfScreen: visibleFrame,
                                     action: action,
                                     lastAction: RawmAction(action: action, subAction: nil, rect: rect, count: count))
}

extension XCTestCase {
    /// Assert two rects are equal within a small floating-point tolerance, reporting
    /// which component differs.
    func assertRectsEqual(_ rect: CGRect,
                          _ expected: CGRect,
                          accuracy: CGFloat = 0.001,
                          file: StaticString = #filePath,
                          line: UInt = #line) {
        XCTAssertEqual(rect.origin.x, expected.origin.x, accuracy: accuracy, "origin.x", file: file, line: line)
        XCTAssertEqual(rect.origin.y, expected.origin.y, accuracy: accuracy, "origin.y", file: file, line: line)
        XCTAssertEqual(rect.width,    expected.width,    accuracy: accuracy, "width",    file: file, line: line)
        XCTAssertEqual(rect.height,   expected.height,   accuracy: accuracy, "height",   file: file, line: line)
    }
}

/// Snapshots the RawmDefaults values that tests commonly mutate and restores them,
/// so global UserDefaults state does not leak between tests.
///
/// Usage:
///   private var defaults: RawmDefaultsSnapshot!
///   override func setUp()    { super.setUp(); defaults = RawmDefaultsSnapshot() }
///   override func tearDown() { defaults.restore(); super.tearDown() }
final class RawmDefaultsSnapshot {
    private let horizontalSplitRatio: Float
    private let verticalSplitRatio: Float
    private let subsequentExecutionMode: SubsequentExecutionMode
    private let cornerCycleExpansionAxis: CornerCycleExpansionAxis
    private let cycleSizesIsChanged: Bool
    private let selectedCycleSizes: Set<CycleSize>
    private let windowSnapping: Bool?

    init() {
        horizontalSplitRatio    = RawmDefaults.horizontalSplitRatio.value
        verticalSplitRatio      = RawmDefaults.verticalSplitRatio.value
        subsequentExecutionMode = RawmDefaults.subsequentExecutionMode.value
        cornerCycleExpansionAxis = RawmDefaults.cornerCycleExpansionAxis.value
        cycleSizesIsChanged     = RawmDefaults.cycleSizesIsChanged.enabled
        selectedCycleSizes      = RawmDefaults.selectedCycleSizes.value
        windowSnapping          = RawmDefaults.windowSnapping.enabled
    }

    func restore() {
        RawmDefaults.horizontalSplitRatio.value    = horizontalSplitRatio
        RawmDefaults.verticalSplitRatio.value      = verticalSplitRatio
        RawmDefaults.subsequentExecutionMode.value = subsequentExecutionMode
        RawmDefaults.cornerCycleExpansionAxis.value = cornerCycleExpansionAxis
        RawmDefaults.cycleSizesIsChanged.enabled   = cycleSizesIsChanged
        RawmDefaults.selectedCycleSizes.value      = selectedCycleSizes
        RawmDefaults.windowSnapping.enabled        = windowSnapping
    }

    /// Set both split ratios at once (a common test setup).
    func setSplitRatio(_ percent: Float) {
        RawmDefaults.horizontalSplitRatio.value = percent
        RawmDefaults.verticalSplitRatio.value = percent
    }
}
