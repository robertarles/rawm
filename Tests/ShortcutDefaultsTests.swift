/// ShortcutDefaultsTests.swift
///
/// Unit tests for CycleSize, SubsequentExecutionMode, WindowAction properties,
/// WindowActionCategory, RawmDefaults typed defaults, and ShortcutMigration helpers.
///
/// Coverage goals: all CycleSize cases (fraction / percentValue / matching tolerance),
/// SubsequentExecutionDefault computed properties, WindowAction category / isDragSnappable /
/// aliasName / name / displayName / displayIndex, WindowActionCategory menuOrder /
/// displayName, RawmDefaults typed round-trips (BoolDefault, OptionalBoolDefault,
/// FloatDefault, IntDefault, CycleSizesDefault, SubsequentExecutionDefault,
/// IntEnumDefault), RawmDefaults.array completeness, and ShellAction / ClipboardAction
/// defaultsKey construction.

import XCTest
@testable import rawm

// MARK: - CycleSizeExtraTests

class CycleSizeExtraTests: XCTestCase {

    // MARK: fraction / percentValue for all cases

    func testAllFractionsMatchExpectedValues() {
        XCTAssertEqual(CycleSize.oneHalf.fraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(CycleSize.twoThirds.fraction, Float(2) / Float(3), accuracy: 0.0001)
        XCTAssertEqual(CycleSize.oneThird.fraction, Float(1) / Float(3), accuracy: 0.0001)
        XCTAssertEqual(CycleSize.oneQuarter.fraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(CycleSize.threeQuarters.fraction, 0.75, accuracy: 0.0001)
    }

    func testPercentValueIsHundredTimesFraction() {
        for size in CycleSize.allCases {
            XCTAssertEqual(size.percentValue, size.fraction * 100, accuracy: 0.0001,
                           "percentValue should be 100 * fraction for \(size)")
        }
    }

    func testOneQuarterPercentValue() {
        XCTAssertEqual(CycleSize.oneQuarter.percentValue, 25, accuracy: 0.001)
    }

    func testThreeQuartersPercentValue() {
        XCTAssertEqual(CycleSize.threeQuarters.percentValue, 75, accuracy: 0.001)
    }

    // MARK: title strings

    func testTitlesAreNonEmpty() {
        XCTAssertFalse(CycleSize.oneHalf.title.isEmpty)
        XCTAssertFalse(CycleSize.twoThirds.title.isEmpty)
        XCTAssertFalse(CycleSize.oneThird.title.isEmpty)
        XCTAssertFalse(CycleSize.oneQuarter.title.isEmpty)
        XCTAssertFalse(CycleSize.threeQuarters.title.isEmpty)
    }

    func testExpectedTitleSymbols() {
        XCTAssertEqual(CycleSize.oneHalf.title, "½")
        XCTAssertEqual(CycleSize.twoThirds.title, "⅔")
        XCTAssertEqual(CycleSize.oneThird.title, "⅓")
        XCTAssertEqual(CycleSize.oneQuarter.title, "¼")
        XCTAssertEqual(CycleSize.threeQuarters.title, "¾")
    }

    // MARK: matching(percentValue:) — boundary / tolerance

    func testMatchingExactOneHalf() {
        XCTAssertEqual(CycleSize.matching(percentValue: 50.0), .oneHalf)
    }

    func testMatchingExactOneQuarter() {
        XCTAssertEqual(CycleSize.matching(percentValue: 25.0), .oneQuarter)
    }

    func testMatchingExactThreeQuarters() {
        XCTAssertEqual(CycleSize.matching(percentValue: 75.0), .threeQuarters)
    }

    func testMatchingAtLowerToleranceBoundary() {
        let tolerance = CycleSize.matchingTolerance
        XCTAssertEqual(CycleSize.matching(percentValue: 50.0 - tolerance), .oneHalf)
    }

    func testMatchingAtUpperToleranceBoundary() {
        let tolerance = CycleSize.matchingTolerance
        XCTAssertEqual(CycleSize.matching(percentValue: 50.0 + tolerance), .oneHalf)
    }

    func testMatchingJustOutsideToleranceLow() {
        let justOutside: Float = 50.0 - CycleSize.matchingTolerance - 0.01
        let result = CycleSize.matching(percentValue: justOutside)
        XCTAssertNil(result, "Value just outside tolerance should not match oneHalf")
    }

    func testMatchingJustOutsideToleranceHigh() {
        let justOutside: Float = 50.0 + CycleSize.matchingTolerance + 0.01
        let result = CycleSize.matching(percentValue: justOutside)
        XCTAssertNil(result, "Value just outside tolerance should not match oneHalf")
    }

    func testMatchingAbsurdValueReturnsNil() {
        XCTAssertNil(CycleSize.matching(percentValue: 0))
        XCTAssertNil(CycleSize.matching(percentValue: 100))
        XCTAssertNil(CycleSize.matching(percentValue: -10))
        XCTAssertNil(CycleSize.matching(percentValue: 45))
    }

    // MARK: matches(percentValue:tolerance:) — custom tolerance

    func testMatchesWithLargerCustomTolerance() {
        XCTAssertTrue(CycleSize.oneHalf.matches(percentValue: 47, tolerance: 5))
    }

    func testMatchesWithZeroTolerance() {
        XCTAssertTrue(CycleSize.oneHalf.matches(percentValue: 50, tolerance: 0))
        XCTAssertFalse(CycleSize.oneHalf.matches(percentValue: 50.001, tolerance: 0))
    }

    // MARK: sortedSizes order

    func testSortedSizesStartsWithFirstSize() {
        XCTAssertEqual(CycleSize.sortedSizes.first, CycleSize.firstSize)
    }

    func testSortedSizesContainsAllCases() {
        let sorted = Set(CycleSize.sortedSizes)
        let all = Set(CycleSize.allCases)
        XCTAssertEqual(sorted, all)
    }

    func testSortedSizesHasCorrectCount() {
        XCTAssertEqual(CycleSize.sortedSizes.count, CycleSize.allCases.count)
    }

    // MARK: defaultSizes

    func testDefaultSizesContainsExpectedPresets() {
        XCTAssertTrue(CycleSize.defaultSizes.contains(.oneHalf))
        XCTAssertTrue(CycleSize.defaultSizes.contains(.twoThirds))
        XCTAssertTrue(CycleSize.defaultSizes.contains(.oneThird))
    }

    func testDefaultSizesDoesNotContainQuarters() {
        XCTAssertFalse(CycleSize.defaultSizes.contains(.oneQuarter))
        XCTAssertFalse(CycleSize.defaultSizes.contains(.threeQuarters))
    }

    // MARK: fromBits / toBits round-trip

    func testBitsRoundTripAllCases() {
        let original: Set<CycleSize> = [.oneHalf, .oneThird, .twoThirds]
        let bits = original.toBits()
        let restored = CycleSize.fromBits(bits: bits)
        XCTAssertEqual(restored, original)
    }

    func testBitsRoundTripSingleCase() {
        for size in CycleSize.allCases {
            let bits = Set([size]).toBits()
            let restored = CycleSize.fromBits(bits: bits)
            XCTAssertEqual(restored, [size])
        }
    }

    func testBitsRoundTripEmpty() {
        let empty: Set<CycleSize> = []
        let bits = empty.toBits()
        XCTAssertEqual(bits, 0)
        let restored = CycleSize.fromBits(bits: bits)
        XCTAssertTrue(restored.isEmpty)
    }

    func testBitsRoundTripAllCasesSet() {
        let all = Set(CycleSize.allCases)
        let bits = all.toBits()
        let restored = CycleSize.fromBits(bits: bits)
        XCTAssertEqual(restored, all)
    }

    // MARK: rawValue integrity

    func testRawValuesAreDistinct() {
        let rawValues = CycleSize.allCases.map { $0.rawValue }
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }
}

// MARK: - SubsequentExecutionModeTests

class SubsequentExecutionModeTests: XCTestCase {

    private var snapshot: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = RawmDefaultsSnapshot()
    }

    override func tearDown() {
        snapshot.restore()
        super.tearDown()
    }

    // MARK: resizes property

    func testResizesModeResizes() {
        RawmDefaults.subsequentExecutionMode.value = .resize
        XCTAssertTrue(RawmDefaults.subsequentExecutionMode.resizes)
    }

    func testAcrossMonitorDoesNotResize() {
        RawmDefaults.subsequentExecutionMode.value = .acrossMonitor
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.resizes)
    }

    func testNoneModeDoesNotResize() {
        RawmDefaults.subsequentExecutionMode.value = .none
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.resizes)
    }

    func testAcrossAndResizeResizes() {
        RawmDefaults.subsequentExecutionMode.value = .acrossAndResize
        XCTAssertTrue(RawmDefaults.subsequentExecutionMode.resizes)
    }

    func testCycleMonitorDoesNotResize() {
        RawmDefaults.subsequentExecutionMode.value = .cycleMonitor
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.resizes)
    }

    func testResizeAndCycleQuadrantsResizes() {
        RawmDefaults.subsequentExecutionMode.value = .resizeAndCycleQuadrants
        XCTAssertTrue(RawmDefaults.subsequentExecutionMode.resizes)
    }

    // MARK: cyclesQuadrantPositions property

    func testOnlyResizeAndCycleQuadrantsCyclesQuadrants() {
        let nonCycling: [SubsequentExecutionMode] = [.resize, .acrossMonitor, .none, .acrossAndResize, .cycleMonitor]

        RawmDefaults.subsequentExecutionMode.value = .resizeAndCycleQuadrants
        XCTAssertTrue(RawmDefaults.subsequentExecutionMode.cyclesQuadrantPositions)

        for mode in nonCycling {
            RawmDefaults.subsequentExecutionMode.value = mode
            XCTAssertFalse(RawmDefaults.subsequentExecutionMode.cyclesQuadrantPositions,
                           "Expected cyclesQuadrantPositions=false for \(mode)")
        }
    }

    // MARK: traversesDisplays property

    func testAcrossMonitorTraverses() {
        RawmDefaults.subsequentExecutionMode.value = .acrossMonitor
        XCTAssertTrue(RawmDefaults.subsequentExecutionMode.traversesDisplays)
    }

    func testAcrossAndResizeTraverses() {
        RawmDefaults.subsequentExecutionMode.value = .acrossAndResize
        XCTAssertTrue(RawmDefaults.subsequentExecutionMode.traversesDisplays)
    }

    func testResizeModeDoesNotTraverse() {
        RawmDefaults.subsequentExecutionMode.value = .resize
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.traversesDisplays)
    }

    func testNoneModeDoesNotTraverse() {
        RawmDefaults.subsequentExecutionMode.value = .none
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.traversesDisplays)
    }

    func testCycleMonitorDoesNotTraverse() {
        RawmDefaults.subsequentExecutionMode.value = .cycleMonitor
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.traversesDisplays)
    }

    func testResizeAndCycleQuadrantsDoesNotTraverse() {
        RawmDefaults.subsequentExecutionMode.value = .resizeAndCycleQuadrants
        XCTAssertFalse(RawmDefaults.subsequentExecutionMode.traversesDisplays)
    }

    // MARK: rawValue / init

    func testAllRawValuesRoundTrip() {
        for mode in [SubsequentExecutionMode.resize, .acrossMonitor, .none, .acrossAndResize, .cycleMonitor, .resizeAndCycleQuadrants] {
            let restored = SubsequentExecutionMode(rawValue: mode.rawValue)
            XCTAssertEqual(restored, mode)
        }
    }

    func testInvalidRawValueReturnsNil() {
        XCTAssertNil(SubsequentExecutionMode(rawValue: 999))
        XCTAssertNil(SubsequentExecutionMode(rawValue: -1))
    }

    // MARK: CodableDefault round-trip via load/toCodable

    func testToCodableAndLoadRoundTrip() {
        let original = SubsequentExecutionMode.acrossAndResize
        RawmDefaults.subsequentExecutionMode.value = original
        let codable = RawmDefaults.subsequentExecutionMode.toCodable()
        XCTAssertEqual(codable.int, original.rawValue)
        RawmDefaults.subsequentExecutionMode.value = .resize
        RawmDefaults.subsequentExecutionMode.load(from: codable)
        XCTAssertEqual(RawmDefaults.subsequentExecutionMode.value, original)
    }
}

// MARK: - WindowActionPropertyTests

class WindowActionPropertyTests: XCTestCase {

    // MARK: name uniqueness

    func testAllActiveActionsHaveUniqueNames() {
        let names = WindowAction.active.map { $0.name }
        XCTAssertEqual(Set(names).count, names.count, "Duplicate names found in WindowAction.active")
    }

    // MARK: aliasName

    func testSideActionsHaveAliasNames() {
        XCTAssertEqual(WindowAction.leftHalf.aliasName, "leftSide")
        XCTAssertEqual(WindowAction.rightHalf.aliasName, "rightSide")
        XCTAssertEqual(WindowAction.bottomHalf.aliasName, "bottomSide")
        XCTAssertEqual(WindowAction.topHalf.aliasName, "topSide")
        XCTAssertEqual(WindowAction.centerHalf.aliasName, "centerSection")
    }

    func testNonSideActionsHaveNilAliasName() {
        XCTAssertNil(WindowAction.maximize.aliasName)
        XCTAssertNil(WindowAction.center.aliasName)
        XCTAssertNil(WindowAction.firstThird.aliasName)
        XCTAssertNil(WindowAction.topLeft.aliasName)
    }

    // MARK: displayIndex

    func testDisplayActionsHaveSequentialDisplayIndex() {
        XCTAssertEqual(WindowAction.displayOne.displayIndex, 0)
        XCTAssertEqual(WindowAction.displayTwo.displayIndex, 1)
        XCTAssertEqual(WindowAction.displayThree.displayIndex, 2)
        XCTAssertEqual(WindowAction.displayFour.displayIndex, 3)
        XCTAssertEqual(WindowAction.displayFive.displayIndex, 4)
        XCTAssertEqual(WindowAction.displaySix.displayIndex, 5)
        XCTAssertEqual(WindowAction.displaySeven.displayIndex, 6)
        XCTAssertEqual(WindowAction.displayEight.displayIndex, 7)
        XCTAssertEqual(WindowAction.displayNine.displayIndex, 8)
    }

    func testNonDisplayActionsHaveNilDisplayIndex() {
        XCTAssertNil(WindowAction.leftHalf.displayIndex)
        XCTAssertNil(WindowAction.maximize.displayIndex)
        XCTAssertNil(WindowAction.center.displayIndex)
        XCTAssertNil(WindowAction.topLeft.displayIndex)
    }

    // MARK: category

    func testThirdsCategory() {
        let thirdsActions: [WindowAction] = [.firstThird, .centerThird, .lastThird, .firstTwoThirds, .centerTwoThirds, .lastTwoThirds]
        for action in thirdsActions {
            XCTAssertEqual(action.category, .thirds, "\(action) should be .thirds category")
        }
    }

    func testFourthsCategory() {
        let fourthsActions: [WindowAction] = [.firstFourth, .secondFourth, .thirdFourth, .lastFourth, .firstThreeFourths, .centerThreeFourths, .lastThreeFourths]
        for action in fourthsActions {
            XCTAssertEqual(action.category, .fourths, "\(action) should be .fourths category")
        }
    }

    func testSixthsCategory() {
        let sixthsActions: [WindowAction] = [.topLeftSixth, .topCenterSixth, .topRightSixth, .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth]
        for action in sixthsActions {
            XCTAssertEqual(action.category, .sixths, "\(action) should be .sixths category")
        }
    }

    func testEighthsCategory() {
        let eighthsActions: [WindowAction] = [.topLeftEighth, .topCenterLeftEighth, .topCenterRightEighth, .topRightEighth, .bottomLeftEighth, .bottomCenterLeftEighth, .bottomCenterRightEighth, .bottomRightEighth]
        for action in eighthsActions {
            XCTAssertEqual(action.category, .eighths, "\(action) should be .eighths category")
        }
    }

    func testNinthsCategory() {
        let ninthsActions: [WindowAction] = [.topLeftNinth, .topCenterNinth, .topRightNinth, .middleLeftNinth, .middleCenterNinth, .middleRightNinth, .bottomLeftNinth, .bottomCenterNinth, .bottomRightNinth]
        for action in ninthsActions {
            XCTAssertEqual(action.category, .ninths, "\(action) should be .ninths category")
        }
    }

    func testTwelfthsCategory() {
        let twelfthsActions: [WindowAction] = [.topLeftTwelfth, .topCenterLeftTwelfth, .topCenterRightTwelfth, .topRightTwelfth, .middleLeftTwelfth, .middleCenterLeftTwelfth, .middleCenterRightTwelfth, .middleRightTwelfth, .bottomLeftTwelfth, .bottomCenterLeftTwelfth, .bottomCenterRightTwelfth, .bottomRightTwelfth]
        for action in twelfthsActions {
            XCTAssertEqual(action.category, .twelfths, "\(action) should be .twelfths category")
        }
    }

    func testSixteenthsCategory() {
        let sixteenthsActions: [WindowAction] = [
            .topLeftSixteenth, .topCenterLeftSixteenth, .topCenterRightSixteenth, .topRightSixteenth,
            .upperMiddleLeftSixteenth, .upperMiddleCenterLeftSixteenth, .upperMiddleCenterRightSixteenth, .upperMiddleRightSixteenth,
            .lowerMiddleLeftSixteenth, .lowerMiddleCenterLeftSixteenth, .lowerMiddleCenterRightSixteenth, .lowerMiddleRightSixteenth,
            .bottomLeftSixteenth, .bottomCenterLeftSixteenth, .bottomCenterRightSixteenth, .bottomRightSixteenth
        ]
        for action in sixteenthsActions {
            XCTAssertEqual(action.category, .sixteenths, "\(action) should be .sixteenths category")
        }
    }

    func testMoveCategoryActions() {
        XCTAssertEqual(WindowAction.moveLeft.category, .move)
        XCTAssertEqual(WindowAction.moveRight.category, .move)
        XCTAssertEqual(WindowAction.moveUp.category, .move)
        XCTAssertEqual(WindowAction.moveDown.category, .move)
    }

    func testSizeCategoryActions() {
        XCTAssertEqual(WindowAction.almostMaximize.category, .size)
        XCTAssertEqual(WindowAction.maximizeHeight.category, .size)
        XCTAssertEqual(WindowAction.larger.category, .size)
        XCTAssertEqual(WindowAction.smaller.category, .size)
        XCTAssertEqual(WindowAction.largerWidth.category, .size)
        XCTAssertEqual(WindowAction.smallerWidth.category, .size)
        XCTAssertEqual(WindowAction.largerHeight.category, .size)
        XCTAssertEqual(WindowAction.smallerHeight.category, .size)
    }

    func testActionsWithNilCategory() {
        XCTAssertNil(WindowAction.leftHalf.category)
        XCTAssertNil(WindowAction.rightHalf.category)
        XCTAssertNil(WindowAction.maximize.category)
        XCTAssertNil(WindowAction.center.category)
        XCTAssertNil(WindowAction.topLeft.category)
        XCTAssertNil(WindowAction.bottomRight.category)
        XCTAssertNil(WindowAction.restore.category)
        XCTAssertNil(WindowAction.tileAll.category)
        XCTAssertNil(WindowAction.cascadeAll.category)
        XCTAssertNil(WindowAction.specified.category)
    }

    // MARK: isDragSnappable

    func testCommonSnapActionsAreDragSnappable() {
        XCTAssertTrue(WindowAction.leftHalf.isDragSnappable)
        XCTAssertTrue(WindowAction.rightHalf.isDragSnappable)
        XCTAssertTrue(WindowAction.topHalf.isDragSnappable)
        XCTAssertTrue(WindowAction.bottomHalf.isDragSnappable)
        XCTAssertTrue(WindowAction.topLeft.isDragSnappable)
        XCTAssertTrue(WindowAction.topRight.isDragSnappable)
        XCTAssertTrue(WindowAction.bottomLeft.isDragSnappable)
        XCTAssertTrue(WindowAction.bottomRight.isDragSnappable)
        XCTAssertTrue(WindowAction.maximize.isDragSnappable)
        XCTAssertTrue(WindowAction.center.isDragSnappable)
        XCTAssertTrue(WindowAction.firstThird.isDragSnappable)
        XCTAssertTrue(WindowAction.centerHalf.isDragSnappable)
    }

    func testNonSnapActionsAreNotDragSnappable() {
        XCTAssertFalse(WindowAction.restore.isDragSnappable)
        XCTAssertFalse(WindowAction.previousDisplay.isDragSnappable)
        XCTAssertFalse(WindowAction.nextDisplay.isDragSnappable)
        XCTAssertFalse(WindowAction.moveUp.isDragSnappable)
        XCTAssertFalse(WindowAction.moveDown.isDragSnappable)
        XCTAssertFalse(WindowAction.moveLeft.isDragSnappable)
        XCTAssertFalse(WindowAction.moveRight.isDragSnappable)
        XCTAssertFalse(WindowAction.specified.isDragSnappable)
        XCTAssertFalse(WindowAction.customSize.isDragSnappable)
        XCTAssertFalse(WindowAction.reverseAll.isDragSnappable)
        XCTAssertFalse(WindowAction.tileAll.isDragSnappable)
        XCTAssertFalse(WindowAction.cascadeAll.isDragSnappable)
        XCTAssertFalse(WindowAction.larger.isDragSnappable)
        XCTAssertFalse(WindowAction.smaller.isDragSnappable)
        XCTAssertFalse(WindowAction.largerWidth.isDragSnappable)
        XCTAssertFalse(WindowAction.smallerWidth.isDragSnappable)
    }

    func testNinthsAreNotDragSnappable() {
        XCTAssertFalse(WindowAction.topLeftNinth.isDragSnappable)
        XCTAssertFalse(WindowAction.middleCenterNinth.isDragSnappable)
        XCTAssertFalse(WindowAction.bottomRightNinth.isDragSnappable)
    }

    func testDisplayActionsAreNotDragSnappable() {
        XCTAssertFalse(WindowAction.displayOne.isDragSnappable)
        XCTAssertFalse(WindowAction.displayTwo.isDragSnappable)
        XCTAssertFalse(WindowAction.displayNine.isDragSnappable)
    }

    // MARK: name (used as defaults key)

    func testNamesMatchExpectedStrings() {
        XCTAssertEqual(WindowAction.maximize.name, "maximize")
        XCTAssertEqual(WindowAction.center.name, "center")
        XCTAssertEqual(WindowAction.topLeft.name, "topLeft")
        XCTAssertEqual(WindowAction.bottomRight.name, "bottomRight")
        XCTAssertEqual(WindowAction.firstThird.name, "firstThird")
        XCTAssertEqual(WindowAction.displayOne.name, "displayOne")
        XCTAssertEqual(WindowAction.customSize.name, "customSize")
    }

    // MARK: displayName — spot-checks including nil cases

    func testDisplayNamesForKnownActions() {
        XCTAssertNotNil(WindowAction.leftHalf.displayName)
        XCTAssertNotNil(WindowAction.rightHalf.displayName)
        XCTAssertNotNil(WindowAction.maximize.displayName)
        XCTAssertNotNil(WindowAction.topLeft.displayName)
        XCTAssertNotNil(WindowAction.bottomRight.displayName)
    }

    func testDisplayNamesAreNilForInternalActions() {
        XCTAssertNil(WindowAction.topLeftThird.displayName)
        XCTAssertNil(WindowAction.topRightThird.displayName)
        XCTAssertNil(WindowAction.bottomLeftThird.displayName)
        XCTAssertNil(WindowAction.bottomRightThird.displayName)
        XCTAssertNil(WindowAction.doubleHeightUp.displayName)
        XCTAssertNil(WindowAction.doubleHeightDown.displayName)
        XCTAssertNil(WindowAction.halveWidthLeft.displayName)
        XCTAssertNil(WindowAction.halveWidthRight.displayName)
        XCTAssertNil(WindowAction.specified.displayName)
        XCTAssertNil(WindowAction.reverseAll.displayName)
        XCTAssertNil(WindowAction.displayOne.displayName)
        XCTAssertNil(WindowAction.displayNine.displayName)
    }

    func testCustomSizeDisplayName() {
        XCTAssertNotNil(WindowAction.customSize.displayName)
    }

    // MARK: positionCycles for additional cases not covered in PositionCyclesTests

    func testCenterHalfPositionCycles() {
        // centerHalf is a positional half — it cycles like other positional actions
        XCTAssertTrue(WindowAction.centerHalf.positionCycles)
    }

    func testCenterThirdPositionCycles() {
        XCTAssertTrue(WindowAction.centerThird.positionCycles)
    }

    func testDisplayActionsDoNotPositionCycle() {
        XCTAssertFalse(WindowAction.displayOne.positionCycles)
        XCTAssertFalse(WindowAction.displayNine.positionCycles)
    }

    func testDoubleAndHalveActionsDoNotPositionCycle() {
        XCTAssertFalse(WindowAction.doubleHeightUp.positionCycles)
        XCTAssertFalse(WindowAction.doubleHeightDown.positionCycles)
        XCTAssertFalse(WindowAction.doubleWidthLeft.positionCycles)
        XCTAssertFalse(WindowAction.doubleWidthRight.positionCycles)
        XCTAssertFalse(WindowAction.halveHeightUp.positionCycles)
        XCTAssertFalse(WindowAction.halveHeightDown.positionCycles)
        XCTAssertFalse(WindowAction.halveWidthLeft.positionCycles)
        XCTAssertFalse(WindowAction.halveWidthRight.positionCycles)
    }

    func testTwelfthsPositionCycle() {
        XCTAssertTrue(WindowAction.middleCenterLeftTwelfth.positionCycles)
        XCTAssertTrue(WindowAction.topRightTwelfth.positionCycles)
    }

    // MARK: rawValue init

    func testInitFromRawValue() {
        XCTAssertEqual(WindowAction(rawValue: 0), .leftHalf)
        XCTAssertEqual(WindowAction(rawValue: 1), .rightHalf)
        XCTAssertEqual(WindowAction(rawValue: 2), .maximize)
        XCTAssertEqual(WindowAction(rawValue: 129), .customSize)
    }

    func testInitFromInvalidRawValueReturnsNil() {
        XCTAssertNil(WindowAction(rawValue: 999))
        XCTAssertNil(WindowAction(rawValue: -1))
        XCTAssertNil(WindowAction(rawValue: 7)) // gap in enum raw values
    }
}

// MARK: - WindowActionCategoryTests

class WindowActionCategoryTests: XCTestCase {

    // MARK: menuOrder

    func testMenuOrderValues() {
        XCTAssertEqual(WindowActionCategory.size.menuOrder, 0)
        XCTAssertEqual(WindowActionCategory.move.menuOrder, 1)
        XCTAssertEqual(WindowActionCategory.thirds.menuOrder, 2)
        XCTAssertEqual(WindowActionCategory.fourths.menuOrder, 3)
        XCTAssertEqual(WindowActionCategory.sixths.menuOrder, 4)
        XCTAssertEqual(WindowActionCategory.eighths.menuOrder, 5)
        XCTAssertEqual(WindowActionCategory.ninths.menuOrder, 6)
        XCTAssertEqual(WindowActionCategory.twelfths.menuOrder, 7)
        XCTAssertEqual(WindowActionCategory.sixteenths.menuOrder, 8)
    }

    func testOtherCategoriesHaveFallbackMenuOrder() {
        XCTAssertEqual(WindowActionCategory.halves.menuOrder, 99)
        XCTAssertEqual(WindowActionCategory.corners.menuOrder, 99)
        XCTAssertEqual(WindowActionCategory.max.menuOrder, 99)
        XCTAssertEqual(WindowActionCategory.display.menuOrder, 99)
        XCTAssertEqual(WindowActionCategory.other.menuOrder, 99)
    }

    // MARK: displayName

    func testDisplayNamesAreNonEmpty() {
        let allCases: [WindowActionCategory] = [.halves, .corners, .thirds, .max, .size, .display, .move, .other, .sixths, .fourths, .eighths, .ninths, .twelfths, .sixteenths]
        for category in allCases {
            XCTAssertFalse(category.displayName.isEmpty, "displayName should not be empty for \(category)")
        }
    }
}

// MARK: - RawmDefaultsRoundTripTests

class RawmDefaultsRoundTripTests: XCTestCase {

    private var snapshot: RawmDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = RawmDefaultsSnapshot()
    }

    override func tearDown() {
        snapshot.restore()
        super.tearDown()
    }

    // MARK: RawmDefaults.array keys completeness

    func testArrayContainsManyEntries() {
        XCTAssertGreaterThan(RawmDefaults.array.count, 50, "RawmDefaults.array should have many entries")
    }

    func testArrayContainsExpectedKeys() {
        let keys = Set(RawmDefaults.array.map { $0.key })
        let required = [
            "launchOnLogin", "disabledApps", "hideMenubarIcon",
            "alternateDefaultShortcuts", "subsequentExecutionMode", "selectedCycleSizes",
            "cycleSizesIsChanged", "cornerCycleExpansionAxis", "allowAnyShortcut",
            "windowSnapping", "almostMaximizeHeight", "almostMaximizeWidth",
            "gapSize", "skipGapTopEdge", "horizontalSplitRatio", "verticalSplitRatio",
            "footprintAlpha", "footprintBorderWidth",
            "cyclingOverlapOffset", "cyclingOverlapOffsetSize", "cyclingOverlapMaxCascade",
            "greenButtonOverride"
        ]
        for key in required {
            XCTAssertTrue(keys.contains(key), "Expected key '\(key)' in RawmDefaults.array")
        }
    }

    // MARK: BoolDefault round-trip via CodableDefault

    func testBoolDefaultTrueToCodableAndLoad() {
        let saved = RawmDefaults.launchOnLogin.enabled
        defer { RawmDefaults.launchOnLogin.enabled = saved }

        RawmDefaults.launchOnLogin.enabled = true
        let codable = RawmDefaults.launchOnLogin.toCodable()
        XCTAssertEqual(codable.bool, true)

        RawmDefaults.launchOnLogin.enabled = false
        RawmDefaults.launchOnLogin.load(from: codable)
        XCTAssertTrue(RawmDefaults.launchOnLogin.enabled)
    }

    func testBoolDefaultFalseRoundTrip() {
        let saved = RawmDefaults.launchOnLogin.enabled
        defer { RawmDefaults.launchOnLogin.enabled = saved }

        RawmDefaults.launchOnLogin.enabled = false
        let codable = RawmDefaults.launchOnLogin.toCodable()
        XCTAssertEqual(codable.bool, false)

        RawmDefaults.launchOnLogin.enabled = true
        RawmDefaults.launchOnLogin.load(from: codable)
        XCTAssertFalse(RawmDefaults.launchOnLogin.enabled)
    }

    // MARK: OptionalBoolDefault round-trip

    func testOptionalBoolDefaultTrueRoundTrip() {
        let saved = RawmDefaults.windowSnapping.enabled
        defer { RawmDefaults.windowSnapping.enabled = saved }

        RawmDefaults.windowSnapping.enabled = true
        let codable = RawmDefaults.windowSnapping.toCodable()
        XCTAssertEqual(codable.int, 1)

        RawmDefaults.windowSnapping.enabled = nil
        RawmDefaults.windowSnapping.load(from: codable)
        XCTAssertEqual(RawmDefaults.windowSnapping.enabled, true)
    }

    func testOptionalBoolDefaultFalseRoundTrip() {
        let saved = RawmDefaults.windowSnapping.enabled
        defer { RawmDefaults.windowSnapping.enabled = saved }

        RawmDefaults.windowSnapping.enabled = false
        let codable = RawmDefaults.windowSnapping.toCodable()
        XCTAssertEqual(codable.int, 2)

        RawmDefaults.windowSnapping.enabled = nil
        RawmDefaults.windowSnapping.load(from: codable)
        XCTAssertEqual(RawmDefaults.windowSnapping.enabled, false)
    }

    func testOptionalBoolDefaultNilRoundTrip() {
        let saved = RawmDefaults.windowSnapping.enabled
        defer { RawmDefaults.windowSnapping.enabled = saved }

        RawmDefaults.windowSnapping.enabled = nil
        let codable = RawmDefaults.windowSnapping.toCodable()
        XCTAssertEqual(codable.int, 0)

        RawmDefaults.windowSnapping.enabled = true
        RawmDefaults.windowSnapping.load(from: codable)
        XCTAssertNil(RawmDefaults.windowSnapping.enabled)
    }

    func testOptionalBoolDefaultComputedProperties() {
        let saved = RawmDefaults.windowSnapping.enabled
        defer { RawmDefaults.windowSnapping.enabled = saved }

        RawmDefaults.windowSnapping.enabled = true
        XCTAssertTrue(RawmDefaults.windowSnapping.userEnabled)
        XCTAssertFalse(RawmDefaults.windowSnapping.userDisabled)
        XCTAssertFalse(RawmDefaults.windowSnapping.notSet)

        RawmDefaults.windowSnapping.enabled = false
        XCTAssertFalse(RawmDefaults.windowSnapping.userEnabled)
        XCTAssertTrue(RawmDefaults.windowSnapping.userDisabled)
        XCTAssertFalse(RawmDefaults.windowSnapping.notSet)

        RawmDefaults.windowSnapping.enabled = nil
        XCTAssertFalse(RawmDefaults.windowSnapping.userEnabled)
        XCTAssertFalse(RawmDefaults.windowSnapping.userDisabled)
        XCTAssertTrue(RawmDefaults.windowSnapping.notSet)
    }

    // MARK: FloatDefault round-trip

    func testFloatDefaultRoundTrip() {
        let saved = RawmDefaults.gapSize.value
        defer { RawmDefaults.gapSize.value = saved }

        RawmDefaults.gapSize.value = 12.5
        let codable = RawmDefaults.gapSize.toCodable()
        XCTAssertEqual(codable.float ?? 0, 12.5, accuracy: 0.001)

        RawmDefaults.gapSize.value = 0
        RawmDefaults.gapSize.load(from: codable)
        XCTAssertEqual(RawmDefaults.gapSize.value, 12.5, accuracy: 0.001)
    }

    func testFloatDefaultCGFloatConversion() {
        let saved = RawmDefaults.footprintAlpha.value
        defer { RawmDefaults.footprintAlpha.value = saved }

        RawmDefaults.footprintAlpha.value = 0.7
        let cgFloat = RawmDefaults.footprintAlpha.cgFloat
        XCTAssertEqual(cgFloat, CGFloat(0.7), accuracy: 0.001)
    }

    // MARK: IntDefault round-trip

    func testIntDefaultRoundTrip() {
        let saved = RawmDefaults.cyclingOverlapMaxCascade.value
        defer { RawmDefaults.cyclingOverlapMaxCascade.value = saved }

        RawmDefaults.cyclingOverlapMaxCascade.value = 3
        let codable = RawmDefaults.cyclingOverlapMaxCascade.toCodable()
        XCTAssertEqual(codable.int, 3)

        RawmDefaults.cyclingOverlapMaxCascade.value = 1
        RawmDefaults.cyclingOverlapMaxCascade.load(from: codable)
        XCTAssertEqual(RawmDefaults.cyclingOverlapMaxCascade.value, 3)
    }

    // MARK: CycleSizesDefault round-trip

    func testCycleSizesDefaultRoundTrip() {
        let original: Set<CycleSize> = [.twoThirds, .oneThird, .threeQuarters]
        let saved = RawmDefaults.selectedCycleSizes.value
        defer { RawmDefaults.selectedCycleSizes.value = saved }

        RawmDefaults.selectedCycleSizes.value = original
        let codable = RawmDefaults.selectedCycleSizes.toCodable()
        XCTAssertNotNil(codable.int)

        RawmDefaults.selectedCycleSizes.value = []
        RawmDefaults.selectedCycleSizes.load(from: codable)
        XCTAssertEqual(RawmDefaults.selectedCycleSizes.value, original)
    }

    func testCycleSizesDefaultEmptyRoundTrip() {
        let saved = RawmDefaults.selectedCycleSizes.value
        defer { RawmDefaults.selectedCycleSizes.value = saved }

        RawmDefaults.selectedCycleSizes.value = []
        let codable = RawmDefaults.selectedCycleSizes.toCodable()
        XCTAssertEqual(codable.int, 0)
        RawmDefaults.selectedCycleSizes.load(from: codable)
        XCTAssertTrue(RawmDefaults.selectedCycleSizes.value.isEmpty)
    }

    // MARK: IntEnumDefault round-trip (CornerCycleExpansionAxis)

    func testIntEnumDefaultVerticalRoundTrip() {
        let saved = RawmDefaults.cornerCycleExpansionAxis.value
        defer { RawmDefaults.cornerCycleExpansionAxis.value = saved }

        RawmDefaults.cornerCycleExpansionAxis.value = .vertical
        let codable = RawmDefaults.cornerCycleExpansionAxis.toCodable()
        XCTAssertEqual(codable.int, CornerCycleExpansionAxis.vertical.rawValue)

        RawmDefaults.cornerCycleExpansionAxis.value = .horizontal
        RawmDefaults.cornerCycleExpansionAxis.load(from: codable)
        XCTAssertEqual(RawmDefaults.cornerCycleExpansionAxis.value, .vertical)
    }

    func testIntEnumDefaultHorizontalRoundTrip() {
        let saved = RawmDefaults.cornerCycleExpansionAxis.value
        defer { RawmDefaults.cornerCycleExpansionAxis.value = saved }

        RawmDefaults.cornerCycleExpansionAxis.value = .horizontal
        let codable = RawmDefaults.cornerCycleExpansionAxis.toCodable()
        XCTAssertEqual(codable.int, CornerCycleExpansionAxis.horizontal.rawValue)
    }

    // MARK: splitRatio defaults

    func testHorizontalSplitRatioRoundTrip() {
        let saved = RawmDefaults.horizontalSplitRatio.value
        defer { RawmDefaults.horizontalSplitRatio.value = saved }

        RawmDefaults.horizontalSplitRatio.value = 66.0
        let codable = RawmDefaults.horizontalSplitRatio.toCodable()
        XCTAssertEqual(codable.float ?? 0, 66.0, accuracy: 0.001)
        RawmDefaults.horizontalSplitRatio.load(from: codable)
        XCTAssertEqual(RawmDefaults.horizontalSplitRatio.value, 66.0, accuracy: 0.001)
    }
}

// MARK: - RawmActionTypesTests

class RawmActionTypesTests: XCTestCase {

    // MARK: ClipboardAction

    func testClipboardActionShowHistoryNameIsNonEmpty() {
        XCTAssertFalse(ClipboardAction.showHistory.name.isEmpty)
    }

    func testClipboardActionShowHistoryDefaultsKeyHasNoDots() {
        let key = ClipboardAction.showHistory.defaultsKey
        XCTAssertFalse(key.isEmpty)
        XCTAssertFalse(key.contains("."), "defaultsKey must not contain dots (MASShortcutBinder constraint)")
        XCTAssertFalse(key.contains(" "), "defaultsKey must not contain spaces")
    }

    func testClipboardActionShowHistoryDefaultsKeyHasExpectedPrefix() {
        XCTAssertTrue(ClipboardAction.showHistory.defaultsKey.hasPrefix("rawmClipboard"))
    }

    func testClipboardActionPasteItemDefaultsKeyHasNoDots() {
        for index in 0..<5 {
            let key = ClipboardAction.pasteItem(index: index).defaultsKey
            XCTAssertFalse(key.contains("."), "defaultsKey must not contain dots for index \(index)")
            XCTAssertFalse(key.contains(" "), "defaultsKey must not contain spaces for index \(index)")
        }
    }

    func testClipboardActionPasteItemIndexedNames() {
        // index 0 → name includes "1" (1-based display)
        let name0 = ClipboardAction.pasteItem(index: 0).name
        let name4 = ClipboardAction.pasteItem(index: 4).name
        XCTAssertTrue(name0.contains("1"))
        XCTAssertTrue(name4.contains("5"))
    }

    // MARK: ShellAction

    func testShellActionDefaultsKeyHasNoDots() {
        let action = ShellAction(name: "Test", command: "open -a WezTerm")
        XCTAssertFalse(action.defaultsKey.contains("."),
                       "defaultsKey must not contain dots (MASShortcutBinder constraint)")
    }

    func testShellActionDefaultsKeyHasNoSpaces() {
        let action = ShellAction(name: "Test", command: "open -a WezTerm")
        XCTAssertFalse(action.defaultsKey.contains(" "))
    }

    func testShellActionDefaultsKeyHasPrefix() {
        let action = ShellAction(name: "Open Claude", command: "open -a Claude")
        XCTAssertTrue(action.defaultsKey.hasPrefix("rawmShell_"))
    }

    func testShellActionCustomDefaultsKey() {
        let action = ShellAction(name: "Test", command: "echo hello", defaultsKey: "myCustomKey")
        XCTAssertEqual(action.defaultsKey, "myCustomKey")
    }

    func testShellActionNameIsStored() {
        let action = ShellAction(name: "Open Finder", command: "open -a Finder")
        XCTAssertEqual(action.name, "Open Finder")
    }

    func testShellActionCommandIsStored() {
        let cmd = "open -a WezTerm"
        let action = ShellAction(name: "WezTerm", command: cmd)
        XCTAssertEqual(action.command, cmd)
    }

    func testShellActionDefaultsKeyIsCommandDerivedNotNameDerived() {
        let a1 = ShellAction(name: "Name A", command: "open -a Claude")
        let a2 = ShellAction(name: "Name B", command: "open -a Claude")
        XCTAssertEqual(a1.defaultsKey, a2.defaultsKey)
    }

    func testShellActionWithSpecialCharactersInCommandSanitizesKey() {
        let action = ShellAction(name: "Test", command: "open -a \"Microsoft Teams\"")
        XCTAssertFalse(action.defaultsKey.contains("\""))
        XCTAssertFalse(action.defaultsKey.contains(" "))
        XCTAssertFalse(action.defaultsKey.contains("."))
    }

    // MARK: WindowActionItem

    func testWindowActionItemUsesDisplayNameWhenAvailable() {
        let item = WindowActionItem(windowAction: .leftHalf)
        XCTAssertFalse(item.name.isEmpty)
        XCTAssertEqual(item.name, WindowAction.leftHalf.displayName)
    }

    func testWindowActionItemFallsBackToNameWhenDisplayNameIsNil() {
        let item = WindowActionItem(windowAction: .topLeftThird)
        XCTAssertNil(WindowAction.topLeftThird.displayName)
        XCTAssertEqual(item.name, WindowAction.topLeftThird.name)
    }

    func testWindowActionItemDefaultsKeyEqualsActionName() {
        let item = WindowActionItem(windowAction: .maximize)
        XCTAssertEqual(item.defaultsKey, WindowAction.maximize.name)
    }

    // MARK: HotkeyRegistry

    func testHotkeyRegistryAllActionsForDisplayContainsWindowActions() {
        let all = HotkeyRegistry.shared.allActionsForDisplay
        let firstWindowActionName = WindowAction.active[0].name
        XCTAssertTrue(all.contains(where: { $0.defaultsKey == firstWindowActionName }),
                      "allActionsForDisplay should include window actions")
    }
}

// MARK: - ShortcutMigrationKeyTests

class ShortcutMigrationKeyTests: XCTestCase {

    /// Verify migrateIfNeeded is idempotent — calling it when already done must not crash.
    func testMigrateIfNeededIsIdempotentWhenAlreadyRun() {
        // Call twice — if already done the guard returns early; must not crash either way.
        ShortcutMigration.migrateIfNeeded()
        ShortcutMigration.migrateIfNeeded()
    }

    /// The private removeStaleOldFormatKeys uses hasPrefix for "rawm.shell." and "rawm.clipboard.".
    func testStaleKeyPatternMatchesDottedPrefixes() {
        let stale = ["rawm.shell.foo", "rawm.clipboard.bar", "rawm.shell.openWezterm"]
        let notStale = ["rawmShell_foo", "rawmClipboardShowHistory", "leftHalf", "centerHalf"]

        for key in stale {
            XCTAssertTrue(key.hasPrefix("rawm.shell.") || key.hasPrefix("rawm.clipboard."),
                          "\(key) should match stale prefix pattern")
        }
        for key in notStale {
            XCTAssertFalse(key.hasPrefix("rawm.shell.") || key.hasPrefix("rawm.clipboard."),
                           "\(key) should not match stale prefix pattern")
        }
    }

    /// Window action names used by ShortcutMigration must not contain dots.
    func testWindowActionNamesUsedByMigrationHaveNoDots() {
        let migrationActions: [WindowAction] = [
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .maximize, .centerHalf, .centerTwoThirds,
            .firstTwoThirds, .lastTwoThirds,
            .previousDisplay, .nextDisplay
        ]
        for action in migrationActions {
            XCTAssertFalse(action.name.contains("."),
                           "action.name '\(action.name)' must not contain dots")
        }
    }

    /// ClipboardAction.showHistory defaultsKey must not contain dots.
    func testClipboardShowHistoryDefaultsKeyHasNoDots() {
        let key = ClipboardAction.showHistory.defaultsKey
        XCTAssertFalse(key.contains("."),
                       "ClipboardAction.showHistory.defaultsKey '\(key)' must not contain dots")
    }

    /// All window action names must not contain dots.
    func testAllWindowActionNamesHaveNoDots() {
        for action in WindowAction.active {
            XCTAssertFalse(action.name.contains("."),
                           "WindowAction '\(action.name)' must not contain dots")
        }
    }
}

// MARK: - CornerCycleExpansionAxisTests

class CornerCycleExpansionAxisTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(CornerCycleExpansionAxis.horizontal.rawValue, 0)
        XCTAssertEqual(CornerCycleExpansionAxis.vertical.rawValue, 1)
    }

    func testInitFromRawValue() {
        XCTAssertEqual(CornerCycleExpansionAxis(rawValue: 0), .horizontal)
        XCTAssertEqual(CornerCycleExpansionAxis(rawValue: 1), .vertical)
        XCTAssertNil(CornerCycleExpansionAxis(rawValue: 2))
        XCTAssertNil(CornerCycleExpansionAxis(rawValue: -1))
    }
}
