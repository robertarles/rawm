/// WindowCalculationTests.swift
///
/// Comprehensive tests for Sources/WindowCalculation/ calculators.
/// Uses TestScreens, rectParams, repeatedRectParams, assertRectsEqual from TestSupport.swift.

import XCTest
@testable import rawm

// Provide Defaults as an alias for RawmDefaults so that the legacy RawmTests.swift
// (which still uses the old name) continues to compile in this worktree.

// MARK: - Maximize / MaximizeHeight / AlmostMaximize

class MaximizeCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testMaximizeStandard() {
        let r = WindowCalculationFactory.maximizeCalculation.calculateRect(rectParams(.maximize)).rect
        assertRectsEqual(r, TestScreens.standard)
    }

    func testMaximizeFullHD() {
        let r = WindowCalculationFactory.maximizeCalculation.calculateRect(rectParams(.maximize, visibleFrame: TestScreens.fullHD)).rect
        assertRectsEqual(r, TestScreens.fullHD)
    }

    func testMaximizeNegativeOrigin() {
        let r = WindowCalculationFactory.maximizeCalculation.calculateRect(rectParams(.maximize, visibleFrame: TestScreens.negativeOrigin)).rect
        assertRectsEqual(r, TestScreens.negativeOrigin)
    }

    func testMaximizeTiny() {
        let r = WindowCalculationFactory.maximizeCalculation.calculateRect(rectParams(.maximize, visibleFrame: TestScreens.tiny)).rect
        assertRectsEqual(r, TestScreens.tiny)
    }

    func testMaximizeHeightPreservesXAndWidth() {
        let win = CGRect(x: 100, y: 200, width: 400, height: 300)
        let r = WindowCalculationFactory.maxHeightCalculation.calculateRect(rectParams(.maximizeHeight, windowRect: win)).rect
        XCTAssertEqual(r.origin.x, 100, accuracy: 0.001)
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, TestScreens.standard.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, TestScreens.standard.height, accuracy: 0.001)
    }

    func testMaximizeHeightFullHD() {
        let vf = TestScreens.fullHD
        let win = CGRect(x: 500, y: 200, width: 300, height: 100)
        let r = WindowCalculationFactory.maxHeightCalculation.calculateRect(rectParams(.maximizeHeight, visibleFrame: vf, windowRect: win)).rect
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, vf.height, accuracy: 0.001)
        XCTAssertEqual(r.width, 300, accuracy: 0.001)
    }

    func testAlmostMaximizeStandard() {
        // AlmostMaximize uses 0.9 default fractions
        let calc = AlmostMaximizeCalculation()
        let vf = TestScreens.standard
        let r = calc.calculateRect(rectParams(.almostMaximize)).rect
        XCTAssertEqual(r.width, round(vf.width * 0.9), accuracy: 1.0)
        XCTAssertEqual(r.height, round(vf.height * 0.9), accuracy: 1.0)
        // Should be centered
        XCTAssertEqual(r.midX, vf.midX, accuracy: 1.0)
        XCTAssertEqual(r.midY, vf.midY, accuracy: 1.0)
    }

    func testAlmostMaximizeResultIsWithinVisibleFrame() {
        let calc = AlmostMaximizeCalculation()
        let r = calc.calculateRect(rectParams(.almostMaximize)).rect
        let vf = TestScreens.standard
        XCTAssertGreaterThanOrEqual(r.minX, vf.minX)
        XCTAssertGreaterThanOrEqual(r.minY, vf.minY)
        XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 1)
        XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 1)
    }
}

// MARK: - Center

class CenterCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() { super.setUp(); snap = RawmDefaultsSnapshot() }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testCenterSmallWindowInStandard() {
        let vf = TestScreens.standard
        let win = CGRect(x: 0, y: 0, width: 400, height: 300)
        let r = WindowCalculationFactory.centerCalculation.calculateRect(rectParams(.center, windowRect: win)).rect
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.height, 300, accuracy: 0.001)
        XCTAssertEqual(r.midX, vf.midX, accuracy: 1.0)
        XCTAssertEqual(r.midY, vf.midY, accuracy: 1.0)
    }

    func testCenterWindowTooWideClampedToWidth() {
        let vf = TestScreens.standard
        let win = CGRect(x: 0, y: 0, width: 2000, height: 300)
        let r = WindowCalculationFactory.centerCalculation.calculateRect(rectParams(.center, windowRect: win)).rect
        XCTAssertEqual(r.width, vf.width, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
    }

    func testCenterWindowTooTallClampedToHeight() {
        let vf = TestScreens.standard
        let win = CGRect(x: 0, y: 0, width: 300, height: 2000)
        let r = WindowCalculationFactory.centerCalculation.calculateRect(rectParams(.center, windowRect: win)).rect
        XCTAssertEqual(r.height, vf.height, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testCenterWindowExceedsBothDimensionsMaximizes() {
        let vf = TestScreens.standard
        let win = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let r = WindowCalculationFactory.centerCalculation.calculateRect(rectParams(.center, windowRect: win)).rect
        assertRectsEqual(r, vf)
    }

    func testCenterNegativeOriginScreen() {
        let vf = TestScreens.negativeOrigin
        let win = CGRect(x: 0, y: 0, width: 400, height: 300)
        let r = WindowCalculationFactory.centerCalculation.calculateRect(rectParams(.center, visibleFrame: vf, windowRect: win)).rect
        XCTAssertEqual(r.midX, vf.midX, accuracy: 1.0)
        XCTAssertEqual(r.midY, vf.midY, accuracy: 1.0)
    }
}

// MARK: - Halves

class HalvesCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.horizontalSplitRatio.value = 50
        RawmDefaults.verticalSplitRatio.value = 50
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.cycleSizesIsChanged.enabled = false
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    // Left / right halves at 50%
    func testLeftHalfStandard() {
        let r = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf)).rect
        assertRectsEqual(r, CGRect(x: 10, y: 20, width: 600, height: 900))
    }

    func testRightHalfStandard() {
        let r = WindowCalculationFactory.rightHalfCalculation.calculateRect(rectParams(.rightHalf)).rect
        assertRectsEqual(r, CGRect(x: 610, y: 20, width: 600, height: 900))
    }

    func testTopHalfStandard() {
        // topHalf is leading vertical side with 50% fraction → height=450, top half
        let r = WindowCalculationFactory.topHalfCalculation.calculateRect(rectParams(.topHalf)).rect
        assertRectsEqual(r, CGRect(x: 10, y: 470, width: 1200, height: 450))
    }

    func testBottomHalfStandard() {
        let r = WindowCalculationFactory.bottomHalfCalculation.calculateRect(rectParams(.bottomHalf)).rect
        assertRectsEqual(r, CGRect(x: 10, y: 20, width: 1200, height: 450))
    }

    func testCenterHalfStandard() {
        // centerHalf landscape: 50% width, centered
        let r = WindowCalculationFactory.centerHalfCalculation.calculateRect(rectParams(.centerHalf)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.width, round(vf.width * 0.5), accuracy: 1.0)
        XCTAssertEqual(r.midX, vf.midX, accuracy: 1.0)
    }

    // With custom split ratio
    func testLeftHalfSixtyPercent() {
        RawmDefaults.horizontalSplitRatio.value = 60
        let r = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf)).rect
        assertRectsEqual(r, CGRect(x: 10, y: 20, width: 720, height: 900))
    }

    func testRightHalfSixtyPercent() {
        RawmDefaults.horizontalSplitRatio.value = 60
        let r = WindowCalculationFactory.rightHalfCalculation.calculateRect(rectParams(.rightHalf)).rect
        assertRectsEqual(r, CGRect(x: 730, y: 20, width: 480, height: 900))
    }

    func testLeftAndRightHalvesFillScreen() {
        let vf = TestScreens.standard
        let l = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf)).rect
        let rr = WindowCalculationFactory.rightHalfCalculation.calculateRect(rectParams(.rightHalf)).rect
        XCTAssertEqual(l.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(rr.maxX, vf.maxX, accuracy: 1.0)
        // They should be adjacent (approximately)
        XCTAssertLessThanOrEqual(abs(l.maxX - rr.minX), 1.0)
    }

    func testTopAndBottomHalvesFillScreen() {
        let vf = TestScreens.standard
        let t = WindowCalculationFactory.topHalfCalculation.calculateRect(rectParams(.topHalf)).rect
        let b = WindowCalculationFactory.bottomHalfCalculation.calculateRect(rectParams(.bottomHalf)).rect
        XCTAssertEqual(t.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(b.minY, vf.minY, accuracy: 0.001)
    }

    // On tiny screen
    func testHalvesOnTinyScreen() {
        let vf = TestScreens.tiny
        let l = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf, visibleFrame: vf)).rect
        XCTAssertEqual(l.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertGreaterThan(l.width, 0)
    }

    func testHalvesResultWithinVisibleFrame() {
        for vf in [TestScreens.standard, TestScreens.fullHD, TestScreens.retina, TestScreens.negativeOrigin] {
            let l = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf, visibleFrame: vf)).rect
            XCTAssertGreaterThanOrEqual(l.minX, vf.minX - 0.5)
            XCTAssertLessThanOrEqual(l.maxX, vf.maxX + 0.5)
        }
    }
}

// MARK: - Thirds

class ThirdsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testFirstThirdStandard() {
        let r = WindowCalculationFactory.firstThirdCalculation.calculateRect(rectParams(.firstThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.width, floor(vf.width / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.height, vf.height, accuracy: 0.001)
    }

    func testCenterThirdStandard() {
        let r = WindowCalculationFactory.centerThirdCalculation.calculateRect(rectParams(.centerThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX + floor(vf.width / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.height, vf.height, accuracy: 0.001)
    }

    func testLastThirdStandard() {
        let r = WindowCalculationFactory.lastThirdCalculation.calculateRect(rectParams(.lastThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 3.0), accuracy: 0.001)
    }

    func testThreeThirdsFillScreen() {
        let vf = TestScreens.standard
        let f = WindowCalculationFactory.firstThirdCalculation.calculateRect(rectParams(.firstThird)).rect
        let c = WindowCalculationFactory.centerThirdCalculation.calculateRect(rectParams(.centerThird)).rect
        let l = WindowCalculationFactory.lastThirdCalculation.calculateRect(rectParams(.lastThird)).rect
        XCTAssertEqual(f.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(l.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertLessThanOrEqual(abs(f.maxX - c.minX), 1.0)
    }

    func testFirstTwoThirdsStandard() {
        let r = WindowCalculationFactory.firstTwoThirdsCalculation.calculateRect(rectParams(.firstTwoThirds)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.width, floor(vf.width * 2.0 / 3.0), accuracy: 0.001)
    }

    func testLastTwoThirdsStandard() {
        let r = WindowCalculationFactory.lastTwoThirdsCalculation.calculateRect(rectParams(.lastTwoThirds)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width * 2.0 / 3.0), accuracy: 0.001)
    }

    func testCenterTwoThirdsStandard() {
        let r = WindowCalculationFactory.centerTwoThirdsCalculation.calculateRect(rectParams(.centerTwoThirds)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.midX, vf.midX, accuracy: 1.0)
    }

    func testVerticalTopThirdStandard() {
        let r = WindowCalculationFactory.topVerticalThirdCalculation.calculateRect(rectParams(.topVerticalThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.height, floor(vf.height / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.width, vf.width, accuracy: 0.001)
    }

    func testVerticalMiddleThirdStandard() {
        let r = WindowCalculationFactory.middleVerticalThirdCalculation.calculateRect(rectParams(.middleVerticalThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.y, vf.minY + floor(vf.height / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.width, vf.width, accuracy: 0.001)
    }

    func testVerticalBottomThirdStandard() {
        let r = WindowCalculationFactory.bottomVerticalThirdCalculation.calculateRect(rectParams(.bottomVerticalThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 3.0), accuracy: 0.001)
    }

    func testVerticalTopTwoThirdsStandard() {
        let r = WindowCalculationFactory.topVerticalTwoThirdsCalculation.calculateRect(rectParams(.topVerticalTwoThirds)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.height, floor(vf.height * 2.0 / 3.0), accuracy: 0.001)
    }

    func testVerticalBottomTwoThirdsStandard() {
        let r = WindowCalculationFactory.bottomVerticalTwoThirdsCalculation.calculateRect(rectParams(.bottomVerticalTwoThirds)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height * 2.0 / 3.0), accuracy: 0.001)
    }

    func testThirdsResultWithinFrame() {
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.firstThirdCalculation, .firstThird),
            (WindowCalculationFactory.centerThirdCalculation, .centerThird),
            (WindowCalculationFactory.lastThirdCalculation, .lastThird),
            (WindowCalculationFactory.topVerticalThirdCalculation, .topVerticalThird),
            (WindowCalculationFactory.middleVerticalThirdCalculation, .middleVerticalThird),
            (WindowCalculationFactory.bottomVerticalThirdCalculation, .bottomVerticalThird),
        ]
        let vf = TestScreens.standard
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }
}

// MARK: - Fourths / Three-Fourths

class FourthsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testFirstFourthStandard() {
        let r = WindowCalculationFactory.firstFourthCalculation.calculateRect(rectParams(.firstFourth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
    }

    func testSecondFourthStandard() {
        let r = WindowCalculationFactory.secondFourthCalculation.calculateRect(rectParams(.secondFourth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX + floor(vf.width / 4.0), accuracy: 0.001)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
    }

    func testThirdFourthStandard() {
        let r = WindowCalculationFactory.thirdFourthCalculation.calculateRect(rectParams(.thirdFourth)).rect
        let vf = TestScreens.standard
        XCTAssertLessThanOrEqual(abs(r.maxX - vf.maxX + floor(vf.width / 4.0)), 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
    }

    func testLastFourthStandard() {
        let r = WindowCalculationFactory.lastFourthCalculation.calculateRect(rectParams(.lastFourth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
    }

    func testFirstThreeFourthsStandard() {
        let r = WindowCalculationFactory.firstThreeFourthsCalculation.calculateRect(rectParams(.firstThreeFourths)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.width, floor(vf.width * 3.0 / 4.0), accuracy: 0.001)
    }

    func testLastThreeFourthsStandard() {
        let r = WindowCalculationFactory.lastThreeFourthsCalculation.calculateRect(rectParams(.lastThreeFourths)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width * 3.0 / 4.0), accuracy: 0.001)
    }

    func testCenterThreeFourthsStandard() {
        let r = WindowCalculationFactory.centerThreeFourthsCalculation.calculateRect(rectParams(.centerThreeFourths)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.midX, vf.midX, accuracy: 2.0)
    }

    func testFourthsResultWithinFrame() {
        let vf = TestScreens.standard
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.firstFourthCalculation, .firstFourth),
            (WindowCalculationFactory.secondFourthCalculation, .secondFourth),
            (WindowCalculationFactory.thirdFourthCalculation, .thirdFourth),
            (WindowCalculationFactory.lastFourthCalculation, .lastFourth),
            (WindowCalculationFactory.firstThreeFourthsCalculation, .firstThreeFourths),
            (WindowCalculationFactory.lastThreeFourthsCalculation, .lastThreeFourths),
        ]
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
        }
    }
}

// MARK: - Corners

class CornersCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.horizontalSplitRatio.value = 50
        RawmDefaults.verticalSplitRatio.value = 50
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.cycleSizesIsChanged.enabled = false
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftCornerStandard() {
        let r = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        assertRectsEqual(r, CGRect(x: 10, y: 470, width: 600, height: 450))
    }

    func testTopRightCornerStandard() {
        let r = WindowCalculationFactory.upperRightCalculation.calculateRect(rectParams(.topRight)).rect
        assertRectsEqual(r, CGRect(x: 610, y: 470, width: 600, height: 450))
    }

    func testBottomLeftCornerStandard() {
        let r = WindowCalculationFactory.lowerLeftCalculation.calculateRect(rectParams(.bottomLeft)).rect
        assertRectsEqual(r, CGRect(x: 10, y: 20, width: 600, height: 450))
    }

    func testBottomRightCornerStandard() {
        let r = WindowCalculationFactory.lowerRightCalculation.calculateRect(rectParams(.bottomRight)).rect
        assertRectsEqual(r, CGRect(x: 610, y: 20, width: 600, height: 450))
    }

    func testCornersCoverEntireScreen() {
        let tl = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        let tr = WindowCalculationFactory.upperRightCalculation.calculateRect(rectParams(.topRight)).rect
        let bl = WindowCalculationFactory.lowerLeftCalculation.calculateRect(rectParams(.bottomLeft)).rect
        let br = WindowCalculationFactory.lowerRightCalculation.calculateRect(rectParams(.bottomRight)).rect
        let vf = TestScreens.standard

        XCTAssertEqual(tl.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(tr.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(bl.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(tl.maxY, vf.maxY, accuracy: 1.0)
    }

    func testCornersOnNegativeOriginScreen() {
        let vf = TestScreens.negativeOrigin
        for (calc, action) in [(WindowCalculationFactory.upperLeftCalculation as WindowCalculation, WindowAction.topLeft),
                               (WindowCalculationFactory.upperRightCalculation, .topRight),
                               (WindowCalculationFactory.lowerLeftCalculation, .bottomLeft),
                               (WindowCalculationFactory.lowerRightCalculation, .bottomRight)] {
            let r = calc.calculateRect(rectParams(action, visibleFrame: vf)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }

    func testCornersCustomSplitRatio() {
        RawmDefaults.horizontalSplitRatio.value = 60
        RawmDefaults.verticalSplitRatio.value = 60
        let tl = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        assertRectsEqual(tl, CGRect(x: 10, y: 380, width: 720, height: 540))
    }
}

// MARK: - Sixths

class SixthsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftSixthStandard() {
        let r = WindowCalculationFactory.topLeftSixthCalculation.calculateRect(rectParams(.topLeftSixth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 2.0), accuracy: 0.001)
    }

    func testTopCenterSixthStandard() {
        let r = WindowCalculationFactory.topCenterSixthCalculation.calculateRect(rectParams(.topCenterSixth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 3.0), accuracy: 0.001)
    }

    func testTopRightSixthStandard() {
        let r = WindowCalculationFactory.topRightSixthCalculation.calculateRect(rectParams(.topRightSixth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
    }

    func testBottomLeftSixthStandard() {
        let r = WindowCalculationFactory.bottomLeftSixthCalculation.calculateRect(rectParams(.bottomLeftSixth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testBottomCenterSixthStandard() {
        let r = WindowCalculationFactory.bottomCenterSixthCalculation.calculateRect(rectParams(.bottomCenterSixth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 2.0), accuracy: 0.001)
    }

    func testBottomRightSixthStandard() {
        let r = WindowCalculationFactory.bottomRightSixthCalculation.calculateRect(rectParams(.bottomRightSixth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testSixthsResultWithinFrame() {
        let vf = TestScreens.standard
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.topLeftSixthCalculation, .topLeftSixth),
            (WindowCalculationFactory.topCenterSixthCalculation, .topCenterSixth),
            (WindowCalculationFactory.topRightSixthCalculation, .topRightSixth),
            (WindowCalculationFactory.bottomLeftSixthCalculation, .bottomLeftSixth),
            (WindowCalculationFactory.bottomCenterSixthCalculation, .bottomCenterSixth),
            (WindowCalculationFactory.bottomRightSixthCalculation, .bottomRightSixth),
        ]
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }
}

// MARK: - Eighths

class EighthsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftEighthStandard() {
        let r = WindowCalculationFactory.topLeftEighthCalculation.calculateRect(rectParams(.topLeftEighth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 2.0), accuracy: 0.001)
    }

    func testTopRightEighthStandard() {
        let r = WindowCalculationFactory.topRightEighthCalculation.calculateRect(rectParams(.topRightEighth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
    }

    func testBottomLeftEighthStandard() {
        let r = WindowCalculationFactory.bottomLeftEighthCalculation.calculateRect(rectParams(.bottomLeftEighth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testBottomRightEighthStandard() {
        let r = WindowCalculationFactory.bottomRightEighthCalculation.calculateRect(rectParams(.bottomRightEighth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testEighthsResultWithinFrame() {
        let vf = TestScreens.standard
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.topLeftEighthCalculation, .topLeftEighth),
            (WindowCalculationFactory.topCenterLeftEighthCalculation, .topCenterLeftEighth),
            (WindowCalculationFactory.topCenterRightEighthCalculation, .topCenterRightEighth),
            (WindowCalculationFactory.topRightEighthCalculation, .topRightEighth),
            (WindowCalculationFactory.bottomLeftEighthCalculation, .bottomLeftEighth),
            (WindowCalculationFactory.bottomCenterLeftEighthCalculation, .bottomCenterLeftEighth),
            (WindowCalculationFactory.bottomCenterRightEighthCalculation, .bottomCenterRightEighth),
            (WindowCalculationFactory.bottomRightEighthCalculation, .bottomRightEighth),
        ]
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }
}

// MARK: - Ninths

class NinthsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftNinthStandard() {
        let r = WindowCalculationFactory.topLeftNinthCalculation.calculateRect(rectParams(.topLeftNinth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 3.0), accuracy: 0.001)
    }

    func testMiddleCenterNinthStandard() {
        let r = WindowCalculationFactory.middleCenterNinthCalculation.calculateRect(rectParams(.middleCenterNinth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.midX, vf.midX, accuracy: 1.0)
        XCTAssertEqual(r.midY, vf.midY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 3.0), accuracy: 0.001)
    }

    func testBottomRightNinthStandard() {
        let r = WindowCalculationFactory.bottomRightNinthCalculation.calculateRect(rectParams(.bottomRightNinth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testNineNinthsFillScreen() {
        let vf = TestScreens.standard
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.topLeftNinthCalculation, .topLeftNinth),
            (WindowCalculationFactory.topCenterNinthCalculation, .topCenterNinth),
            (WindowCalculationFactory.topRightNinthCalculation, .topRightNinth),
            (WindowCalculationFactory.middleLeftNinthCalculation, .middleLeftNinth),
            (WindowCalculationFactory.middleCenterNinthCalculation, .middleCenterNinth),
            (WindowCalculationFactory.middleRightNinthCalculation, .middleRightNinth),
            (WindowCalculationFactory.bottomLeftNinthCalculation, .bottomLeftNinth),
            (WindowCalculationFactory.bottomCenterNinthCalculation, .bottomCenterNinth),
            (WindowCalculationFactory.bottomRightNinthCalculation, .bottomRightNinth),
        ]
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }
}

// MARK: - Twelfths

class TwelfthsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftTwelfthStandard() {
        let r = WindowCalculationFactory.topLeftTwelfthCalculation.calculateRect(rectParams(.topLeftTwelfth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 3.0), accuracy: 0.001)
    }

    func testBottomRightTwelfthStandard() {
        let r = WindowCalculationFactory.bottomRightTwelfthCalculation.calculateRect(rectParams(.bottomRightTwelfth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testTwelfthsResultWithinFrame() {
        let vf = TestScreens.standard
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.topLeftTwelfthCalculation, .topLeftTwelfth),
            (WindowCalculationFactory.topCenterLeftTwelfthCalculation, .topCenterLeftTwelfth),
            (WindowCalculationFactory.topCenterRightTwelfthCalculation, .topCenterRightTwelfth),
            (WindowCalculationFactory.topRightTwelfthCalculation, .topRightTwelfth),
            (WindowCalculationFactory.middleLeftTwelfthCalculation, .middleLeftTwelfth),
            (WindowCalculationFactory.middleCenterLeftTwelfthCalculation, .middleCenterLeftTwelfth),
            (WindowCalculationFactory.middleCenterRightTwelfthCalculation, .middleCenterRightTwelfth),
            (WindowCalculationFactory.middleRightTwelfthCalculation, .middleRightTwelfth),
            (WindowCalculationFactory.bottomLeftTwelfthCalculation, .bottomLeftTwelfth),
            (WindowCalculationFactory.bottomCenterLeftTwelfthCalculation, .bottomCenterLeftTwelfth),
            (WindowCalculationFactory.bottomCenterRightTwelfthCalculation, .bottomCenterRightTwelfth),
            (WindowCalculationFactory.bottomRightTwelfthCalculation, .bottomRightTwelfth),
        ]
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }
}

// MARK: - Sixteenths

class SixteenthsCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftSixteenthStandard() {
        let r = WindowCalculationFactory.topLeftSixteenthCalculation.calculateRect(rectParams(.topLeftSixteenth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width / 4.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 4.0), accuracy: 0.001)
    }

    func testBottomRightSixteenthStandard() {
        let r = WindowCalculationFactory.bottomRightSixteenthCalculation.calculateRect(rectParams(.bottomRightSixteenth)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testSixteenthsResultWithinFrame() {
        let vf = TestScreens.standard
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.topLeftSixteenthCalculation, .topLeftSixteenth),
            (WindowCalculationFactory.topCenterLeftSixteenthCalculation, .topCenterLeftSixteenth),
            (WindowCalculationFactory.topCenterRightSixteenthCalculation, .topCenterRightSixteenth),
            (WindowCalculationFactory.topRightSixteenthCalculation, .topRightSixteenth),
            (WindowCalculationFactory.upperMiddleLeftSixteenthCalculation, .upperMiddleLeftSixteenth),
            (WindowCalculationFactory.upperMiddleCenterLeftSixteenthCalculation, .upperMiddleCenterLeftSixteenth),
            (WindowCalculationFactory.upperMiddleCenterRightSixteenthCalculation, .upperMiddleCenterRightSixteenth),
            (WindowCalculationFactory.upperMiddleRightSixteenthCalculation, .upperMiddleRightSixteenth),
            (WindowCalculationFactory.lowerMiddleLeftSixteenthCalculation, .lowerMiddleLeftSixteenth),
            (WindowCalculationFactory.lowerMiddleCenterLeftSixteenthCalculation, .lowerMiddleCenterLeftSixteenth),
            (WindowCalculationFactory.lowerMiddleCenterRightSixteenthCalculation, .lowerMiddleCenterRightSixteenth),
            (WindowCalculationFactory.lowerMiddleRightSixteenthCalculation, .lowerMiddleRightSixteenth),
            (WindowCalculationFactory.bottomLeftSixteenthCalculation, .bottomLeftSixteenth),
            (WindowCalculationFactory.bottomCenterLeftSixteenthCalculation, .bottomCenterLeftSixteenth),
            (WindowCalculationFactory.bottomCenterRightSixteenthCalculation, .bottomCenterRightSixteenth),
            (WindowCalculationFactory.bottomRightSixteenthCalculation, .bottomRightSixteenth),
        ]
        for (calc, action) in calcs {
            let r = calc.calculateRect(rectParams(action)).rect
            XCTAssertGreaterThanOrEqual(r.minX, vf.minX - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxX, vf.maxX + 0.5, "\(action)")
            XCTAssertGreaterThanOrEqual(r.minY, vf.minY - 0.5, "\(action)")
            XCTAssertLessThanOrEqual(r.maxY, vf.maxY + 0.5, "\(action)")
        }
    }
}

// MARK: - Move Left/Right/Up/Down

class MoveCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.resizeOnDirectionalMove.enabled = false
        RawmDefaults.centeredDirectionalMove.enabled = false
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testMoveLeftSnapsToLeftEdge() {
        let vf = TestScreens.standard
        let win = CGRect(x: 400, y: 100, width: 300, height: 200)
        let r = WindowCalculationFactory.moveLeftRightCalculation.calculateRect(rectParams(.moveLeft, windowRect: win)).rect
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.width, 300, accuracy: 0.001)
    }

    func testMoveRightSnapsToRightEdge() {
        let vf = TestScreens.standard
        let win = CGRect(x: 400, y: 100, width: 300, height: 200)
        let r = WindowCalculationFactory.moveLeftRightCalculation.calculateRect(rectParams(.moveRight, windowRect: win)).rect
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.width, 300, accuracy: 0.001)
    }

    func testMoveUpSnapsToTopEdge() {
        let vf = TestScreens.standard
        let win = CGRect(x: 100, y: 200, width: 300, height: 200)
        let r = WindowCalculationFactory.moveUpCalculation.calculateRect(rectParams(.moveUp, windowRect: win)).rect
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.height, 200, accuracy: 0.001)
    }

    func testMoveDownSnapsToBottomEdge() {
        let vf = TestScreens.standard
        let win = CGRect(x: 100, y: 200, width: 300, height: 200)
        let r = WindowCalculationFactory.moveDownCalculation.calculateRect(rectParams(.moveDown, windowRect: win)).rect
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, 200, accuracy: 0.001)
    }

    func testMoveLeftNegativeOriginScreen() {
        let vf = TestScreens.negativeOrigin
        let win = CGRect(x: -1000, y: -100, width: 400, height: 300)
        let r = WindowCalculationFactory.moveLeftRightCalculation.calculateRect(rectParams(.moveLeft, visibleFrame: vf, windowRect: win)).rect
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
    }

    func testMoveFullWidthWindowClampsToScreen() {
        let vf = TestScreens.standard
        let win = CGRect(x: 10, y: 20, width: 1200, height: 900) // full width
        let r = WindowCalculationFactory.moveUpCalculation.calculateRect(rectParams(.moveUp, windowRect: win)).rect
        XCTAssertEqual(r.width, vf.width, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
    }
}

// MARK: - ChangeSize (Larger/Smaller)

class ChangeSizeCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.curtainChangeSize.enabled = false
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    private var sizeOffset: CGFloat { 30.0 } // default

    func testLargerIncreasesWindowByOffset() {
        let win = CGRect(x: 200, y: 100, width: 400, height: 300)
        let r = WindowCalculationFactory.changeSizeCalculation.calculateRect(rectParams(.larger, windowRect: win)).rect
        XCTAssertEqual(r.width, 400 + sizeOffset, accuracy: 1.0)
        XCTAssertEqual(r.height, 300 + sizeOffset, accuracy: 1.0)
    }

    func testSmallerDecreasesWindowByOffset() {
        let win = CGRect(x: 200, y: 100, width: 600, height: 500)
        let r = WindowCalculationFactory.changeSizeCalculation.calculateRect(rectParams(.smaller, windowRect: win)).rect
        XCTAssertEqual(r.width, 600 - sizeOffset, accuracy: 1.0)
        XCTAssertEqual(r.height, 500 - sizeOffset, accuracy: 1.0)
    }

    func testLargerWidthOnlyAffectsWidth() {
        let win = CGRect(x: 200, y: 100, width: 400, height: 300)
        let r = WindowCalculationFactory.changeSizeCalculation.calculateRect(rectParams(.largerWidth, windowRect: win)).rect
        XCTAssertEqual(r.height, 300, accuracy: 0.001)
        XCTAssertGreaterThan(r.width, 400)
    }

    func testSmallerHeightOnlyAffectsHeight() {
        let win = CGRect(x: 200, y: 100, width: 400, height: 500)
        let r = WindowCalculationFactory.changeSizeCalculation.calculateRect(rectParams(.smallerHeight, windowRect: win)).rect
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertLessThan(r.height, 500)
    }

    func testSmallerDoesNotGoTooSmall() {
        let vf = TestScreens.standard
        // A window that is already at minimum size
        let tinyWin = CGRect(x: vf.minX, y: vf.minY, width: 50, height: 50)
        let r = WindowCalculationFactory.changeSizeCalculation.calculateRect(rectParams(.smaller, windowRect: tinyWin)).rect
        // Should return original rect when too small
        XCTAssertEqual(r.width, 50, accuracy: 0.001)
        XCTAssertEqual(r.height, 50, accuracy: 0.001)
    }
}

// MARK: - HalfOrDouble Dimension

class HalfOrDoubleDimensionTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() { super.setUp(); snap = RawmDefaultsSnapshot() }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testHalveHeightDown() {
        // Use a window large enough to survive the 25% minimum check on standard frame (900*0.25=225)
        let win = CGRect(x: 100, y: 20, width: 800, height: 900)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.halveHeightDown, windowRect: win)).rect
        XCTAssertEqual(r.height, 450, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, 20, accuracy: 0.001)
        XCTAssertEqual(r.width, 800, accuracy: 0.001)
    }

    func testHalveHeightUp() {
        let win = CGRect(x: 100, y: 20, width: 800, height: 900)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.halveHeightUp, windowRect: win)).rect
        XCTAssertEqual(r.height, 450, accuracy: 0.001)
        // halveHeightUp: halved rect offset by halved height upward
        XCTAssertEqual(r.origin.y, 20 + 450, accuracy: 0.001)
    }

    func testHalveWidthLeft() {
        // Use a window large enough (min width = floor(1200*0.25) = 300)
        let win = CGRect(x: 10, y: 200, width: 800, height: 600)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.halveWidthLeft, windowRect: win)).rect
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, 10, accuracy: 0.001)
    }

    func testHalveWidthRight() {
        let win = CGRect(x: 10, y: 200, width: 800, height: 600)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.halveWidthRight, windowRect: win)).rect
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, 10 + 400, accuracy: 0.001)
    }

    func testDoubleHeightDown() {
        let win = CGRect(x: 100, y: 200, width: 400, height: 150)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.doubleHeightDown, windowRect: win)).rect
        XCTAssertEqual(r.height, 300, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, 200 - 150, accuracy: 0.001)
    }

    func testDoubleWidthLeft() {
        let win = CGRect(x: 200, y: 100, width: 200, height: 300)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.doubleWidthLeft, windowRect: win)).rect
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, 200 - 200, accuracy: 0.001)
    }

    func testDoubleWidthRight() {
        let win = CGRect(x: 100, y: 100, width: 200, height: 300)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.doubleWidthRight, windowRect: win)).rect
        XCTAssertEqual(r.width, 400, accuracy: 0.001)
        XCTAssertEqual(r.origin.x, 100, accuracy: 0.001)
    }

    func testHalveTooSmallReturnsOriginal() {
        let vf = TestScreens.standard
        // A very small window — halving should return original
        let tinyWin = CGRect(x: vf.minX, y: vf.minY, width: 50, height: 50)
        let r = WindowCalculationFactory.halfOrDoubleDimensionCalculation.calculateRect(rectParams(.halveWidthLeft, windowRect: tinyWin)).rect
        XCTAssertEqual(r.width, 50, accuracy: 0.001)
    }
}

// MARK: - Cycling Behavior (Thirds)

class ThirdsCyclingTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.cycleSizesIsChanged.enabled = false
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testFirstThirdCyclesThroughPositions() {
        let vf = TestScreens.standard

        // First invocation: first third
        let first = WindowCalculationFactory.firstThirdCalculation.calculateRect(rectParams(.firstThird)).rect
        XCTAssertEqual(first.width, floor(vf.width / 3.0), accuracy: 0.001)

        // Repeated with lastSubAction = .leftThird → should become centerThird
        let lastAction = RawmAction(action: .firstThird, subAction: .leftThird, rect: first, count: 1)
        let second = WindowCalculationFactory.firstThirdCalculation.calculateRect(
            rectParams(.firstThird, lastAction: lastAction)).rect
        // center third
        XCTAssertEqual(second.origin.x, vf.minX + floor(vf.width / 3.0), accuracy: 0.001)
    }

    func testLastThirdCyclesBackward() {
        let vf = TestScreens.standard
        let last = WindowCalculationFactory.lastThirdCalculation.calculateRect(rectParams(.lastThird)).rect
        // repeated with .rightThird should cycle to center
        let lastAction = RawmAction(action: .lastThird, subAction: .rightThird, rect: last, count: 1)
        let second = WindowCalculationFactory.lastThirdCalculation.calculateRect(
            rectParams(.lastThird, lastAction: lastAction)).rect
        // should now be center third
        XCTAssertEqual(second.origin.x, vf.minX + floor(vf.width / 3.0), accuracy: 0.001)
    }
}

// MARK: - Corner Cycling Behavior

class CornerCyclingTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.horizontalSplitRatio.value = 50
        RawmDefaults.verticalSplitRatio.value = 50
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.cycleSizesIsChanged.enabled = false
        RawmDefaults.cornerCycleExpansionAxis.value = .horizontal
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testCornerCyclesHorizontallyWithDefaultSizes() {
        // First invocation at 50%
        let firstRect = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        assertRectsEqual(firstRect, CGRect(x: 10, y: 470, width: 600, height: 450))

        // Second invocation (repeated)
        let secondRect = WindowCalculationFactory.upperLeftCalculation.calculateRect(
            repeatedRectParams(.topLeft, currentRect: firstRect)).rect

        // Should cycle to a different width (two-thirds or one-third)
        XCTAssertFalse(firstRect.equalTo(secondRect), "Repeated corner should give different rect")
        XCTAssertEqual(secondRect.maxY, firstRect.maxY, accuracy: 0.001, "Vertical position stays same for horizontal axis")
        XCTAssertEqual(secondRect.origin.y, firstRect.origin.y, accuracy: 0.001)
    }

    func testCornerCyclesVerticallyWhenAxisIsVertical() {
        RawmDefaults.cornerCycleExpansionAxis.value = .vertical
        let firstRect = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        let secondRect = WindowCalculationFactory.upperLeftCalculation.calculateRect(
            repeatedRectParams(.topLeft, currentRect: firstRect)).rect

        XCTAssertFalse(firstRect.equalTo(secondRect))
        XCTAssertEqual(secondRect.origin.x, firstRect.origin.x, accuracy: 0.001, "Horizontal position stays same for vertical axis")
        XCTAssertEqual(secondRect.width, firstRect.width, accuracy: 0.001)
    }

    func testCornerCycleThirdSequenceHorizontal() {
        RawmDefaults.cornerCycleExpansionAxis.value = .horizontal
        RawmDefaults.horizontalSplitRatio.value = Float(CycleSize.twoThirds.percentValue)
        RawmDefaults.verticalSplitRatio.value = Float(CycleSize.twoThirds.percentValue)

        let first = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        let second = WindowCalculationFactory.upperLeftCalculation.calculateRect(
            repeatedRectParams(.topLeft, currentRect: first)).rect
        let third = WindowCalculationFactory.upperLeftCalculation.calculateRect(
            repeatedRectParams(.topLeft, currentRect: second, count: 2)).rect

        XCTAssertFalse(first.equalTo(second))
        XCTAssertFalse(second.equalTo(third))
    }

    func testLowerRightCyclesHorizontally() {
        let firstRect = WindowCalculationFactory.lowerRightCalculation.calculateRect(rectParams(.bottomRight)).rect
        let secondRect = WindowCalculationFactory.lowerRightCalculation.calculateRect(
            repeatedRectParams(.bottomRight, currentRect: firstRect)).rect

        XCTAssertFalse(firstRect.equalTo(secondRect))
        // Bottom-right corner: y position stays the same on horizontal axis
        XCTAssertEqual(secondRect.origin.y, firstRect.origin.y, accuracy: 0.001)
    }

    func testCornerCycleWithNoCycleSizesSelectedFallsBack() {
        RawmDefaults.cycleSizesIsChanged.enabled = true
        RawmDefaults.selectedCycleSizes.value = []

        let first = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft)).rect
        let repeated = WindowCalculationFactory.upperLeftCalculation.calculateRect(
            repeatedRectParams(.topLeft, currentRect: first)).rect
        // Should fall back to first rect (no cycle sizes)
        assertRectsEqual(repeated, first)
    }
}

// MARK: - Half Cycling Behavior

class HalfCyclingTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.horizontalSplitRatio.value = 50
        RawmDefaults.verticalSplitRatio.value = 50
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.cycleSizesIsChanged.enabled = false
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testLeftHalfCyclesWidth() {
        let first = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf)).rect
        let repeated = WindowCalculationFactory.leftHalfCalculation.calculateRepeatedRect(
            repeatedRectParams(.leftHalf, currentRect: first)).rect
        // Should be different (cycling through 2/3, 1/3)
        XCTAssertFalse(first.equalTo(repeated), "Repeated left half should cycle to different width")
        // Origin x stays at left edge
        XCTAssertEqual(repeated.origin.x, first.origin.x, accuracy: 0.001)
    }

    func testRightHalfCyclesWidth() {
        let first = WindowCalculationFactory.rightHalfCalculation.calculateRect(rectParams(.rightHalf)).rect
        let repeated = WindowCalculationFactory.rightHalfCalculation.calculateRepeatedRect(
            repeatedRectParams(.rightHalf, currentRect: first)).rect
        XCTAssertFalse(first.equalTo(repeated))
        let vf = TestScreens.standard
        XCTAssertEqual(repeated.maxX, vf.maxX, accuracy: 1.0)
    }

    func testTopHalfCyclesHeight() {
        let first = WindowCalculationFactory.topHalfCalculation.calculateRect(rectParams(.topHalf)).rect
        let repeated = WindowCalculationFactory.topHalfCalculation.calculateRect(
            repeatedRectParams(.topHalf, currentRect: first)).rect
        XCTAssertFalse(first.equalTo(repeated))
        let vf = TestScreens.standard
        XCTAssertEqual(repeated.maxY, vf.maxY, accuracy: 1.0)
    }

    func testBottomHalfCyclesHeight() {
        let first = WindowCalculationFactory.bottomHalfCalculation.calculateRect(rectParams(.bottomHalf)).rect
        let repeated = WindowCalculationFactory.bottomHalfCalculation.calculateRect(
            repeatedRectParams(.bottomHalf, currentRect: first)).rect
        XCTAssertFalse(first.equalTo(repeated))
        let vf = TestScreens.standard
        XCTAssertEqual(repeated.origin.y, vf.minY, accuracy: 0.001)
    }

    func testCustomCycleSizesAreUsed() {
        RawmDefaults.cycleSizesIsChanged.enabled = true
        RawmDefaults.selectedCycleSizes.value = [.oneThird, .twoThirds]
        RawmDefaults.horizontalSplitRatio.value = 50

        let first = WindowCalculationFactory.leftHalfCalculation.calculateRepeatedRect(
            repeatedRectParams(.leftHalf)).rect
        let vf = TestScreens.standard
        // first should be 2/3 (twoThirds is first in sorted order)
        XCTAssertEqual(first.width, floor(vf.width * 2.0 / 3.0), accuracy: 1.0)
    }

    func testNoCycleSizesReturnsFirstRect() {
        RawmDefaults.cycleSizesIsChanged.enabled = true
        RawmDefaults.selectedCycleSizes.value = []

        let r = WindowCalculationFactory.leftHalfCalculation.calculateRepeatedRect(
            repeatedRectParams(.leftHalf)).rect
        let expected = WindowCalculationFactory.leftHalfCalculation.calculateRect(rectParams(.leftHalf)).rect
        assertRectsEqual(r, expected)
    }
}

// MARK: - HalfSplitFrameCalculation

class HalfSplitFrameCalculationTests: XCTestCase {

    func testHorizontalRectLeadingHalf() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let r = HalfSplitFrameCalculation.horizontalRect(in: vf, side: .leading, fraction: 0.5)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(r.width, 600, accuracy: 0.001)
        XCTAssertEqual(r.height, 900, accuracy: 0.001)
    }

    func testHorizontalRectTrailingHalf() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let r = HalfSplitFrameCalculation.horizontalRect(in: vf, side: .trailing, fraction: 0.5)
        XCTAssertEqual(r.origin.x, 600, accuracy: 0.001)
        XCTAssertEqual(r.width, 600, accuracy: 0.001)
    }

    func testVerticalRectLeadingSide() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let r = HalfSplitFrameCalculation.verticalRect(in: vf, side: .leading, fraction: 0.5)
        XCTAssertEqual(r.height, 450, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, 450, accuracy: 0.001) // leading is top half
    }

    func testVerticalRectTrailingSide() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let r = HalfSplitFrameCalculation.verticalRect(in: vf, side: .trailing, fraction: 0.5)
        XCTAssertEqual(r.height, 450, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, 0, accuracy: 0.001) // trailing is bottom half
    }

    func testCornerRectTopLeft() {
        let vf = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let r = HalfSplitFrameCalculation.cornerRect(in: vf,
                                                     horizontalSide: .leading,
                                                     verticalSide: .leading,
                                                     horizontalFraction: 0.5,
                                                     verticalFraction: 0.5)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(r.maxY, 900, accuracy: 1.0)
        XCTAssertEqual(r.width, 600, accuracy: 0.001)
        XCTAssertEqual(r.height, 450, accuracy: 0.001)
    }

    func testCornerRectBottomRight() {
        let vf = CGRect(x: 10, y: 20, width: 1200, height: 900)
        let r = HalfSplitFrameCalculation.cornerRect(in: vf,
                                                     horizontalSide: .trailing,
                                                     verticalSide: .trailing,
                                                     horizontalFraction: 0.5,
                                                     verticalFraction: 0.5)
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testHorizontalRectWithNonDefaultOrigin() {
        let vf = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let r = HalfSplitFrameCalculation.horizontalRect(in: vf, side: .leading, fraction: 0.5)
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.width, 960, accuracy: 0.001)
    }
}

// MARK: - WindowCalculationFactory.calculationsByAction

class CalculationsByActionTests: XCTestCase {

    func testAllActionsInCalculationsByActionAreNonNil() {
        // Sample of key actions that must be mapped
        let requiredActions: [WindowAction] = [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf, .maximize,
            .maximizeHeight, .almostMaximize, .center, .firstThird,
            .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds,
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .firstFourth, .lastFourth, .firstThreeFourths, .lastThreeFourths,
            .topLeftSixth, .topRightSixth, .bottomLeftSixth, .bottomRightSixth,
            .topLeftNinth, .middleCenterNinth, .bottomRightNinth,
            .topLeftEighth, .bottomRightEighth,
            .topLeftTwelfth, .bottomRightTwelfth,
            .topLeftSixteenth, .bottomRightSixteenth,
            .moveLeft, .moveRight, .moveUp, .moveDown,
            .larger, .smaller, .largerWidth, .smallerWidth, .largerHeight, .smallerHeight,
            .halveHeightUp, .halveHeightDown, .halveWidthLeft, .halveWidthRight,
            .doubleHeightUp, .doubleHeightDown, .doubleWidthLeft, .doubleWidthRight,
            .topVerticalThird, .middleVerticalThird, .bottomVerticalThird,
            .topVerticalTwoThirds, .bottomVerticalTwoThirds,
        ]
        for action in requiredActions {
            XCTAssertNotNil(WindowCalculationFactory.calculationsByAction[action], "Missing calculator for \(action)")
        }
    }
}

// MARK: - Edge Cases / Invariants

class EdgeCaseCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testMaximizeOnTinyScreen() {
        let r = WindowCalculationFactory.maximizeCalculation.calculateRect(rectParams(.maximize, visibleFrame: TestScreens.tiny)).rect
        assertRectsEqual(r, TestScreens.tiny)
    }

    func testTopHalfOnFullHD() {
        let vf = TestScreens.fullHD
        RawmDefaults.verticalSplitRatio.value = 50
        let r = WindowCalculationFactory.topHalfCalculation.calculateRect(rectParams(.topHalf, visibleFrame: vf)).rect
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.height, floor(vf.height / 2.0), accuracy: 0.001)
        XCTAssertEqual(r.width, vf.width, accuracy: 0.001)
    }

    func testBottomHalfOnRetina() {
        let vf = TestScreens.retina
        RawmDefaults.verticalSplitRatio.value = 50
        let r = WindowCalculationFactory.bottomHalfCalculation.calculateRect(rectParams(.bottomHalf, visibleFrame: vf)).rect
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 2.0), accuracy: 0.001)
    }

    func testNegativeOriginCornerStartsAtCorrectX() {
        let vf = TestScreens.negativeOrigin
        RawmDefaults.horizontalSplitRatio.value = 50
        RawmDefaults.verticalSplitRatio.value = 50
        let r = WindowCalculationFactory.upperLeftCalculation.calculateRect(rectParams(.topLeft, visibleFrame: vf)).rect
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertLessThan(r.origin.x, 0)
    }

    func testCenterProminentlyIsAboveCenter() {
        let vf = TestScreens.standard
        let win = CGRect(x: 0, y: 0, width: 600, height: 400)
        let plain = WindowCalculationFactory.centerCalculation.calculateRect(rectParams(.center, windowRect: win)).rect
        let prominent = WindowCalculationFactory.centerProminentlyCalculation.calculateRect(rectParams(.centerProminently, windowRect: win)).rect
        // Center prominently shifts window upward (higher y in AppKit coords)
        XCTAssertGreaterThan(prominent.origin.y, plain.origin.y)
    }

    func testAllStaticCalculatorsReturnNonNullRectForMaximize() {
        let calcs: [WindowCalculation] = [
            WindowCalculationFactory.maximizeCalculation,
            WindowCalculationFactory.maxHeightCalculation,
            WindowCalculationFactory.leftHalfCalculation,
            WindowCalculationFactory.rightHalfCalculation,
            WindowCalculationFactory.topHalfCalculation,
            WindowCalculationFactory.bottomHalfCalculation,
            WindowCalculationFactory.centerCalculation,
        ]
        let params = rectParams(.maximize)
        for calc in calcs {
            let r = calc.calculateRect(params).rect
            XCTAssertFalse(r.isNull, "\(type(of: calc)) returned null rect")
            XCTAssertFalse(r.isInfinite, "\(type(of: calc)) returned infinite rect")
        }
    }
}

// MARK: - Vertical Thirds Cycling

class VerticalThirdsCyclingTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopVerticalThirdCyclesToMiddle() {
        let vf = TestScreens.standard
        let first = WindowCalculationFactory.topVerticalThirdCalculation.calculateRect(rectParams(.topVerticalThird)).rect
        let lastAction = RawmAction(action: .topVerticalThird, subAction: .topThird, rect: first, count: 1)
        let second = WindowCalculationFactory.topVerticalThirdCalculation.calculateRect(rectParams(.topVerticalThird, lastAction: lastAction)).rect
        // Should be middle third
        XCTAssertEqual(second.origin.y, vf.minY + floor(vf.height / 3.0), accuracy: 0.001)
    }

    func testBottomVerticalThirdCyclesToMiddle() {
        let vf = TestScreens.standard
        let first = WindowCalculationFactory.bottomVerticalThirdCalculation.calculateRect(rectParams(.bottomVerticalThird)).rect
        XCTAssertEqual(first.origin.y, vf.minY, accuracy: 0.001)

        let lastAction = RawmAction(action: .bottomVerticalThird, subAction: .bottomThird, rect: first, count: 1)
        let second = WindowCalculationFactory.bottomVerticalThirdCalculation.calculateRect(rectParams(.bottomVerticalThird, lastAction: lastAction)).rect
        // Should become middle third
        XCTAssertEqual(second.origin.y, vf.minY + floor(vf.height / 3.0), accuracy: 0.001)
    }

    func testTopVerticalTwoThirdsCyclesToBottom() {
        let first = WindowCalculationFactory.topVerticalTwoThirdsCalculation.calculateRect(rectParams(.topVerticalTwoThirds)).rect
        let lastAction = RawmAction(action: .topVerticalTwoThirds, subAction: .topTwoThirds, rect: first, count: 1)
        let second = WindowCalculationFactory.topVerticalTwoThirdsCalculation.calculateRect(rectParams(.topVerticalTwoThirds, lastAction: lastAction)).rect
        let vf = TestScreens.standard
        // Should cycle to bottom two-thirds
        XCTAssertEqual(second.origin.y, vf.minY, accuracy: 0.001)
    }
}

// MARK: - Top-Left Thirds (2D Grid)

class TopLeftThirdCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testTopLeftThirdInLandscape() {
        let r = WindowCalculationFactory.topLeftThirdCalculation.calculateRect(rectParams(.topLeftThird)).rect
        let vf = TestScreens.standard
        // landscape: 2/3 width, 1/2 height, at top left
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
        XCTAssertEqual(r.width, floor(vf.width * 2.0 / 3.0), accuracy: 0.001)
        XCTAssertEqual(r.height, floor(vf.height / 2.0), accuracy: 0.001)
    }

    func testTopRightThirdInLandscape() {
        let r = WindowCalculationFactory.topRightThirdCalculation.calculateRect(rectParams(.topRightThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.maxY, vf.maxY, accuracy: 1.0)
    }

    func testBottomLeftThirdInLandscape() {
        let r = WindowCalculationFactory.bottomLeftThirdCalculation.calculateRect(rectParams(.bottomLeftThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.origin.x, vf.minX, accuracy: 0.001)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }

    func testBottomRightThirdInLandscape() {
        let r = WindowCalculationFactory.bottomRightThirdCalculation.calculateRect(rectParams(.bottomRightThird)).rect
        let vf = TestScreens.standard
        XCTAssertEqual(r.maxX, vf.maxX, accuracy: 1.0)
        XCTAssertEqual(r.origin.y, vf.minY, accuracy: 0.001)
    }
}

// MARK: - First/Last TwoThirds Cycling

class TwoThirdsCyclingTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testFirstTwoThirdsCyclesToLast() {
        let vf = TestScreens.standard
        let first = WindowCalculationFactory.firstTwoThirdsCalculation.calculateRect(rectParams(.firstTwoThirds)).rect
        // Repeated with lastSubAction = .leftTwoThirds
        let lastAction = RawmAction(action: .firstTwoThirds, subAction: .leftTwoThirds, rect: first, count: 1)
        let second = WindowCalculationFactory.firstTwoThirdsCalculation.calculateRect(rectParams(.firstTwoThirds, lastAction: lastAction)).rect
        // Should switch to last two-thirds
        XCTAssertEqual(second.maxX, vf.maxX, accuracy: 1.0)
    }

    func testLastTwoThirdsCyclesToFirst() {
        let vf = TestScreens.standard
        let first = WindowCalculationFactory.lastTwoThirdsCalculation.calculateRect(rectParams(.lastTwoThirds)).rect
        let lastAction = RawmAction(action: .lastTwoThirds, subAction: .rightTwoThirds, rect: first, count: 1)
        let second = WindowCalculationFactory.lastTwoThirdsCalculation.calculateRect(rectParams(.lastTwoThirds, lastAction: lastAction)).rect
        XCTAssertEqual(second.origin.x, vf.minX, accuracy: 0.001)
    }
}

// MARK: - ThreeFourths Cycling

class ThreeFourthsCyclingTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    func testFirstThreeFourthsCyclesToLast() {
        let vf = TestScreens.standard
        let first = WindowCalculationFactory.firstThreeFourthsCalculation.calculateRect(rectParams(.firstThreeFourths)).rect
        let lastAction = RawmAction(action: .firstThreeFourths, subAction: .leftThreeFourths, rect: first, count: 1)
        let second = WindowCalculationFactory.firstThreeFourthsCalculation.calculateRect(rectParams(.firstThreeFourths, lastAction: lastAction)).rect
        XCTAssertEqual(second.maxX, vf.maxX, accuracy: 1.0)
    }

    func testLastThreeFourthsCyclesToFirst() {
        let vf = TestScreens.standard
        let last = WindowCalculationFactory.lastThreeFourthsCalculation.calculateRect(rectParams(.lastThreeFourths)).rect
        let lastAction = RawmAction(action: .lastThreeFourths, subAction: .rightThreeFourths, rect: last, count: 1)
        let second = WindowCalculationFactory.lastThreeFourthsCalculation.calculateRect(rectParams(.lastThreeFourths, lastAction: lastAction)).rect
        XCTAssertEqual(second.origin.x, vf.minX, accuracy: 0.001)
    }
}

// MARK: - Multiple Screens (verifying results stay within provided frame)

class MultipleScreensCalculationTests: XCTestCase {
    private var snap: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snap = RawmDefaultsSnapshot()
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.horizontalSplitRatio.value = 50
        RawmDefaults.verticalSplitRatio.value = 50
    }
    override func tearDown() { snap.restore(); super.tearDown() }

    private func assertWithinFrame(_ rect: CGRect, frame: CGRect, label: String) {
        XCTAssertGreaterThanOrEqual(rect.minX, frame.minX - 1.0, "\(label) minX")
        XCTAssertGreaterThanOrEqual(rect.minY, frame.minY - 1.0, "\(label) minY")
        XCTAssertLessThanOrEqual(rect.maxX, frame.maxX + 1.0, "\(label) maxX")
        XCTAssertLessThanOrEqual(rect.maxY, frame.maxY + 1.0, "\(label) maxY")
    }

    func testAllHalvesAcrossAllTestScreens() {
        let screens = [TestScreens.standard, TestScreens.fullHD, TestScreens.retina, TestScreens.tiny, TestScreens.negativeOrigin]
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.leftHalfCalculation, .leftHalf),
            (WindowCalculationFactory.rightHalfCalculation, .rightHalf),
            (WindowCalculationFactory.topHalfCalculation, .topHalf),
            (WindowCalculationFactory.bottomHalfCalculation, .bottomHalf),
        ]
        for vf in screens {
            for (calc, action) in calcs {
                let r = calc.calculateRect(rectParams(action, visibleFrame: vf)).rect
                assertWithinFrame(r, frame: vf, label: "\(action) on \(vf)")
            }
        }
    }

    func testAllCornersAcrossAllTestScreens() {
        let screens = [TestScreens.standard, TestScreens.fullHD, TestScreens.negativeOrigin]
        let calcs: [(WindowCalculation, WindowAction)] = [
            (WindowCalculationFactory.upperLeftCalculation, .topLeft),
            (WindowCalculationFactory.upperRightCalculation, .topRight),
            (WindowCalculationFactory.lowerLeftCalculation, .bottomLeft),
            (WindowCalculationFactory.lowerRightCalculation, .bottomRight),
        ]
        for vf in screens {
            for (calc, action) in calcs {
                let r = calc.calculateRect(rectParams(action, visibleFrame: vf)).rect
                assertWithinFrame(r, frame: vf, label: "\(action) on \(vf)")
            }
        }
    }
}
