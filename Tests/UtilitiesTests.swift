/// UtilitiesTests.swift
///
/// Unit tests for pure helpers and extensions in Sources/Utilities/.
/// Covered: SequenceExtension, CGExtension (isLandscape, centerPoint,
///          numSharedEdges, sharedEdges, screenFlipped null branch),
///          OptionSet.count (via Edge/Dimension), DispatchTimeExtension,
///          NotificationExtension, Debounce, TimeoutCache.
/// Skipped (require live AppKit/AX/run-loop state): AXExtension, WindowUtil,
///   EventMonitor, RunLoopThread, StageUtil, AlertUtil, NSImageExtension,
///   MASShortcutMigration, MacTilingDefaults, CFExtension (unsafe bit-casts),
///   StringExtension (wraps NSLocalizedString, no pure logic to assert).

import XCTest
@testable import rawm

// MARK: - SequenceExtension

final class SequenceExtensionTests: XCTestCase {

    func testUniqueMapPreservesInsertionOrder() {
        let input = [3, 1, 4, 1, 5, 9, 2, 6, 5, 3]
        let result = input.uniqueMap { $0 }
        XCTAssertEqual(result, [3, 1, 4, 5, 9, 2, 6])
    }

    func testUniqueMapOnEmptySequenceReturnsEmpty() {
        let input: [Int] = []
        XCTAssertTrue(input.uniqueMap { $0 }.isEmpty)
    }

    func testUniqueMapAllUniqueElementsPassThrough() {
        let input = [1, 2, 3]
        XCTAssertEqual(input.uniqueMap { $0 }, [1, 2, 3])
    }

    func testUniqueMapAllSameReducesToSingleElement() {
        let input = [7, 7, 7, 7]
        XCTAssertEqual(input.uniqueMap { $0 }, [7])
    }

    func testUniqueMapWithTransformCollapsesDuplicates() {
        // abs(-3) == abs(3) → second occurrence dropped; -3 comes first
        let input = [-3, 1, -1, 3, 2]
        let result = input.uniqueMap { abs($0) }
        XCTAssertEqual(result, [3, 1, 2])
    }

    func testUniqueMapStringTransform() {
        let input = ["foo", "bar", "foo", "baz"]
        XCTAssertEqual(input.uniqueMap { $0.uppercased() }, ["FOO", "BAR", "BAZ"])
    }

    func testUniqueMapSingleElement() {
        XCTAssertEqual([42].uniqueMap { $0 }, [42])
    }

    func testUniqueMapRetainsFirstOccurrenceNotSubsequent() {
        let result = [10, 20, 10, 30].uniqueMap { $0 }
        XCTAssertEqual(result, [10, 20, 30])
    }
}

// MARK: - CGExtension — CGRect pure properties

final class CGRectIsLandscapeTests: XCTestCase {

    func testIsLandscapeWhenWiderThanTall() {
        XCTAssertTrue(CGRect(x: 0, y: 0, width: 200, height: 100).isLandscape)
    }

    func testIsLandscapeFalseWhenTallerThanWide() {
        XCTAssertFalse(CGRect(x: 0, y: 0, width: 100, height: 200).isLandscape)
    }

    func testIsLandscapeFalseForSquare() {
        // Strict ">" — square is NOT landscape
        XCTAssertFalse(CGRect(x: 0, y: 0, width: 100, height: 100).isLandscape)
    }
}

final class CGRectCenterPointTests: XCTestCase {

    func testCenterPointOfUnitRect() {
        let center = CGRect(x: 0, y: 0, width: 2, height: 4).centerPoint
        XCTAssertEqual(center.x, 1, accuracy: 0.001)
        XCTAssertEqual(center.y, 2, accuracy: 0.001)
    }

    func testCenterPointWithNonZeroOrigin() {
        let center = CGRect(x: 10, y: 20, width: 100, height: 200).centerPoint
        XCTAssertEqual(center.x, 60, accuracy: 0.001)
        XCTAssertEqual(center.y, 120, accuracy: 0.001)
    }

    func testCenterPointOfZeroSizeRect() {
        let center = CGRect(x: 5, y: 7, width: 0, height: 0).centerPoint
        XCTAssertEqual(center.x, 5, accuracy: 0.001)
        XCTAssertEqual(center.y, 7, accuracy: 0.001)
    }
}

final class CGRectNumSharedEdgesTests: XCTestCase {

    func testNumSharedEdgesNone() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 200, y: 200, width: 100, height: 100)
        XCTAssertEqual(a.numSharedEdges(withRect: b), 0)
    }

    func testNumSharedEdgesLeftEdgeOnly() {
        let a = CGRect(x: 50, y: 0, width: 100, height: 100)
        let b = CGRect(x: 50, y: 50, width: 80, height: 80)
        XCTAssertEqual(a.numSharedEdges(withRect: b), 1)
    }

    func testNumSharedEdgesRightEdge() {
        // a: x=0..150, y=0..100 ; b: x=50..150, y=0..100
        // Shared: maxX=150 (right), minY=0 (bottom), maxY=100 (top) => 3
        let a = CGRect(x: 0, y: 0, width: 150, height: 100)
        let b = CGRect(x: 50, y: 0, width: 100, height: 100)
        XCTAssertEqual(a.numSharedEdges(withRect: b), 3)
    }

    func testNumSharedEdgesTwoEdges() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 0, y: 0, width: 50, height: 50)
        // minX == minX, minY == minY
        XCTAssertEqual(a.numSharedEdges(withRect: b), 2)
    }

    func testNumSharedEdgesAllFourWhenSameRect() {
        let r = CGRect(x: 10, y: 10, width: 100, height: 100)
        XCTAssertEqual(r.numSharedEdges(withRect: r), 4)
    }
}

final class CGRectSharedEdgesTests: XCTestCase {

    func testSharedEdgesIdenticalRectsReturnAll() {
        let r = CGRect(x: 0, y: 0, width: 100, height: 100)
        let edges = r.sharedEdges(withRect: r)
        XCTAssertTrue(edges.contains(.left))
        XCTAssertTrue(edges.contains(.right))
        XCTAssertTrue(edges.contains(.top))
        XCTAssertTrue(edges.contains(.bottom))
    }

    func testSharedEdgesNoneWhenFarApart() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 5, y: 5, width: 100, height: 100)
        XCTAssertEqual(a.sharedEdges(withRect: b, tolerance: 0), .none)
    }

    func testSharedEdgesWithTolerance() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 1, y: 0, width: 100, height: 100) // minX offset by 1
        let edges = a.sharedEdges(withRect: b, tolerance: 2)
        XCTAssertTrue(edges.contains(.left))
    }

    func testSharedEdgesLeftOnly() {
        // a: x=10..110, y=0..100 ; b: x=10..210, y=50..200
        // shared: minX=10 (left). maxX differs. minY differs. maxY: 100 vs 200 -> differs.
        let a = CGRect(x: 10, y: 0, width: 100, height: 100)  // minX=10, maxX=110, minY=0, maxY=100
        let b = CGRect(x: 10, y: 50, width: 200, height: 150) // minX=10, maxX=210, minY=50, maxY=200
        let edges = a.sharedEdges(withRect: b, tolerance: 0)
        XCTAssertTrue(edges.contains(.left))
        XCTAssertFalse(edges.contains(.right))
        XCTAssertFalse(edges.contains(.top))
        XCTAssertFalse(edges.contains(.bottom))
    }

    func testSharedEdgesTopOnly() {
        // Both have maxY = 100
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 200, y: 50, width: 100, height: 50)
        let edges = a.sharedEdges(withRect: b, tolerance: 0)
        XCTAssertTrue(edges.contains(.top))
        XCTAssertFalse(edges.contains(.bottom))
        XCTAssertFalse(edges.contains(.left))
        XCTAssertFalse(edges.contains(.right))
    }

    func testSharedEdgesBottomOnly() {
        // Both have minY = 0
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 200, y: 0, width: 100, height: 50)
        let edges = a.sharedEdges(withRect: b, tolerance: 0)
        XCTAssertTrue(edges.contains(.bottom))
        XCTAssertFalse(edges.contains(.top))
    }

    func testSharedEdgesCountViaOptionSet() {
        let edges: Edge = [.left, .top]
        XCTAssertEqual(edges.count, 2)
    }
}

// MARK: - CGRect.screenFlipped — null guard branch

final class CGRectScreenFlippedTests: XCTestCase {

    func testScreenFlippedNullRectReturnsNull() {
        XCTAssertTrue(CGRect.null.screenFlipped.isNull)
    }

    func testScreenFlippedPreservesSize() {
        let rect = CGRect(x: 50, y: 100, width: 300, height: 200)
        let flipped = rect.screenFlipped
        XCTAssertEqual(rect.width, flipped.width, accuracy: 0.001)
        XCTAssertEqual(rect.height, flipped.height, accuracy: 0.001)
    }

    func testScreenFlippedPreservesX() {
        let rect = CGRect(x: 250, y: 300, width: 500, height: 400)
        XCTAssertEqual(rect.origin.x, rect.screenFlipped.origin.x, accuracy: 0.001)
    }

    func testScreenFlippedIsOwnInverse() {
        let rect = CGRect(x: 100, y: 200, width: 400, height: 300)
        let result = rect.screenFlipped.screenFlipped
        XCTAssertEqual(rect.origin.x, result.origin.x, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, result.origin.y, accuracy: 0.001)
    }
}

// MARK: - OptionSet.count (via Edge and Dimension)

final class OptionSetCountTests: XCTestCase {

    func testEdgeNoneCountIsZero() {
        XCTAssertEqual(Edge.none.count, 0)
    }

    func testEdgeSingleBitsEachCountOne() {
        XCTAssertEqual(Edge.left.count, 1)
        XCTAssertEqual(Edge.right.count, 1)
        XCTAssertEqual(Edge.top.count, 1)
        XCTAssertEqual(Edge.bottom.count, 1)
    }

    func testEdgeTwoEdgesCountIsTwo() {
        let edges: Edge = [.left, .right]
        XCTAssertEqual(edges.count, 2)
    }

    func testEdgeAllCountIsFour() {
        XCTAssertEqual(Edge.all.count, 4)
    }

    func testDimensionNoneCountIsZero() {
        XCTAssertEqual(Dimension.none.count, 0)
    }

    func testDimensionHorizontalCountIsOne() {
        XCTAssertEqual(Dimension.horizontal.count, 1)
    }

    func testDimensionBothCountIsTwo() {
        XCTAssertEqual(Dimension.both.count, 2)
    }
}

// MARK: - DispatchTimeExtension

final class DispatchTimeExtensionTests: XCTestCase {

    func testUptimeMillisecondsIsPositive() {
        XCTAssertGreaterThan(DispatchTime.now().uptimeMilliseconds, 0)
    }

    func testUptimeMillisecondsNonDecreasing() {
        let before = DispatchTime.now().uptimeMilliseconds
        // Perform work to advance the clock without sleeping
        var sum: UInt64 = 0
        for i in 0..<500_000 { sum &+= UInt64(i) }
        _ = sum
        let after = DispatchTime.now().uptimeMilliseconds
        XCTAssertGreaterThanOrEqual(after, before)
    }

    func testUptimeMillisecondsDeltaForOneSecond() {
        let future = DispatchTime.now() + .seconds(1)
        let now = DispatchTime.now()
        let delta = future.uptimeMilliseconds - now.uptimeMilliseconds
        // Expect ~1000 ms; allow generous ±200 ms for CI scheduling noise
        XCTAssertGreaterThan(delta, 800)
        XCTAssertLessThan(delta, 1200)
    }

    func testUptimeMillisecondsIsDividedByMillion() {
        let t = DispatchTime.now()
        let fromNanos = t.uptimeNanoseconds / 1_000_000
        XCTAssertEqual(t.uptimeMilliseconds, fromNanos)
    }
}

// MARK: - NotificationExtension

final class NotificationNameTests: XCTestCase {

    func testAllStaticNamesAreUnique() {
        let names: [Notification.Name] = [
            .configImported, .windowSnapping, .frontAppChanged, .allowAnyShortcut,
            .changeDefaults, .todoMenuToggled, .appWillBecomeActive,
            .missionControlDragging, .menuBarIconHidden, .windowTitleBar,
            .greenButtonOverride, .defaultSnapAreas, .updateAvailability,
            .showAdditionalSizesInMenuChanged, .shortcutRecording
        ]
        let rawValues = names.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count, "Duplicate Notification.Name raw value detected")
    }

    // Tests below use a private NotificationCenter to avoid triggering app-level observers
    // that are registered on NotificationCenter.default for production notifications.

    func testPostDeliversNotificationToCenter() {
        let center = NotificationCenter()
        var received = false
        let token = Notification.Name.updateAvailability.onPost(center: center) { _ in received = true }
        Notification.Name.updateAvailability.post(center: center)
        center.removeObserver(token)
        XCTAssertTrue(received)
    }

    func testPostToCustomCenterDoesNotArriveOnDefault() {
        let customCenter = NotificationCenter()
        var receivedOnDefault = false
        let token = customCenter.addObserver(
            forName: .updateAvailability, object: nil, queue: nil) { _ in receivedOnDefault = true }
        // Post on the default center — the custom-center observer should not fire
        Notification.Name.updateAvailability.post(center: NotificationCenter.default)
        customCenter.removeObserver(token)
        XCTAssertFalse(receivedOnDefault)
    }

    func testPostDeliversUserInfo() {
        let center = NotificationCenter()
        var receivedValue: Int?
        let token = Notification.Name.updateAvailability.onPost(center: center) { note in
            receivedValue = note.userInfo?["k"] as? Int
        }
        Notification.Name.updateAvailability.post(center: center, userInfo: ["k": 99])
        center.removeObserver(token)
        XCTAssertEqual(receivedValue, 99)
    }

    func testPostDeliversObject() {
        let center = NotificationCenter()
        let sentinel = NSObject()
        var receivedObject: AnyObject?
        let token = Notification.Name.updateAvailability.onPost(center: center, object: sentinel) { note in
            receivedObject = note.object as AnyObject
        }
        Notification.Name.updateAvailability.post(center: center, object: sentinel)
        center.removeObserver(token)
        XCTAssertTrue(receivedObject === sentinel)
    }

    func testOnPostWithCustomCenter() {
        var received = false
        let center = NotificationCenter()
        let token = Notification.Name.shortcutRecording.onPost(center: center) { _ in received = true }
        Notification.Name.shortcutRecording.post(center: center)
        center.removeObserver(token)
        XCTAssertTrue(received)
    }

    func testOnPostWithOperationQueue() {
        let center = NotificationCenter()
        let exp = expectation(description: "received on bg queue")
        let queue = OperationQueue()
        let token = Notification.Name.updateAvailability.onPost(center: center, queue: queue) { _ in exp.fulfill() }
        Notification.Name.updateAvailability.post(center: center)
        wait(for: [exp], timeout: 1)
        center.removeObserver(token)
    }

    // Verify that object-filtered observer does NOT fire when a different object posts
    func testOnPostWithObjectFilterIgnoresDifferentObject() {
        let center = NotificationCenter()
        let sentinel = NSObject()
        let other = NSObject()
        var fired = false
        let token = Notification.Name.updateAvailability.onPost(center: center, object: sentinel) { _ in fired = true }
        Notification.Name.updateAvailability.post(center: center, object: other)
        center.removeObserver(token)
        XCTAssertFalse(fired)
    }
}

// MARK: - Debounce

final class DebounceTests: XCTestCase {

    // When the captured value hasn't changed, perform IS called
    func testDebouncePerformsWhenInputMatchesCurrent() {
        let exp = expectation(description: "perform called")
        let current = 1
        Debounce.input(1, comparedAgainst: current) { _ in exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    // When the captured value changes before the 0.5 s fires, perform is NOT called
    func testDebounceDoesNotPerformWhenInputDiffers() {
        var current = 1
        var performed = false
        Debounce.input(1, comparedAgainst: current) { _ in performed = true }
        current = 99 // mutate before the deadline
        let wait = expectation(description: "wait past debounce window")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { wait.fulfill() }
        waitForExpectations(timeout: 2)
        XCTAssertFalse(performed)
    }

    // perform receives the correct original input value
    func testDebouncePassesInputValueToPerform() {
        let exp = expectation(description: "value check")
        var received: Int?
        let current = 77
        Debounce.input(77, comparedAgainst: current) { val in
            received = val
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        XCTAssertEqual(received, 77)
    }
}

// MARK: - TimeoutCache

final class TimeoutCacheTests: XCTestCase {

    // Basic hit: value retrievable before timeout
    func testGetReturnsStoredValue() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        cache["key"] = 42
        XCTAssertEqual(cache["key"], 42)
    }

    // Miss: key never set
    func testGetReturnsNilForMissingKey() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        XCTAssertNil(cache["missing"])
    }

    // Setting nil removes key
    func testSetNilRemovesExistingKey() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        cache["a"] = 1
        cache["a"] = nil
        XCTAssertNil(cache["a"])
    }

    // Overwrite replaces old value
    func testOverwriteUpdatesValue() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        cache["k"] = 1
        cache["k"] = 2
        XCTAssertEqual(cache["k"], 2)
    }

    // Multiple keys coexist
    func testMultipleKeysAreIndependent() {
        let cache = TimeoutCache<String, String>(timeout: 5_000)
        cache["x"] = "alpha"
        cache["y"] = "beta"
        XCTAssertEqual(cache["x"], "alpha")
        XCTAssertEqual(cache["y"], "beta")
        XCTAssertNil(cache["z"])
    }

    // Integer key type works
    func testIntegerKeyType() {
        let cache = TimeoutCache<Int, String>(timeout: 5_000)
        cache[1] = "one"
        cache[2] = "two"
        XCTAssertEqual(cache[1], "one")
        XCTAssertEqual(cache[2], "two")
        XCTAssertNil(cache[3])
    }

    // Entry expires after its timeout
    func testEntryExpiresAfterTimeout() {
        let cache = TimeoutCache<String, Int>(timeout: 50) // 50 ms
        cache["x"] = 7

        let exp = expectation(description: "wait for expiry")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        XCTAssertNil(cache["x"])
    }

    // After expiry, a new write is readable
    func testWriteAfterExpiryWorks() {
        let cache = TimeoutCache<String, Int>(timeout: 50)
        cache["z"] = 5

        let exp = expectation(description: "expire first entry")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        _ = cache["z"]  // triggers internal removal
        cache["z"] = 99
        XCTAssertEqual(cache["z"], 99)
    }

    // Setting nil on a key that was never set is a no-op
    func testSetNilOnAbsentKeyIsNoop() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        cache["ghost"] = nil
        XCTAssertNil(cache["ghost"])
    }

    // All inserted entries expire together
    func testAllEntriesExpire() {
        let cache = TimeoutCache<Int, String>(timeout: 50)
        for i in 0..<5 { cache[i] = "v\(i)" }

        let exp = expectation(description: "all expire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        for i in 0..<5 { XCTAssertNil(cache[i]) }
    }

    // Long-lived entries survive past the short-lived entries' expiry
    func testLongLivedEntriesSurvivePurge() {
        let shortCache = TimeoutCache<Int, String>(timeout: 50)
        let longCache = TimeoutCache<Int, String>(timeout: 5_000)

        for i in 0..<3 { shortCache[i] = "short\(i)" }
        for i in 10..<13 { longCache[i] = "long\(i)" }

        let exp = expectation(description: "short entries expire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        // Trigger purge by reading expired keys
        for i in 0..<3 { _ = shortCache[i] }

        for i in 10..<13 { XCTAssertNotNil(longCache[i]) }
    }

    // Overwrite a key with nil then re-insert; linked-list consistency
    func testRemoveAndReinsertSingleKey() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        cache["a"] = 1
        cache["a"] = nil
        cache["a"] = 2
        XCTAssertEqual(cache["a"], 2)
    }

    // Insert three entries, remove middle by nil, verify head and tail are intact
    func testRemoveMiddleEntryLinkedListConsistency() {
        let cache = TimeoutCache<String, Int>(timeout: 5_000)
        cache["a"] = 1
        cache["b"] = 2
        cache["c"] = 3
        cache["b"] = nil
        XCTAssertEqual(cache["a"], 1)
        XCTAssertNil(cache["b"])
        XCTAssertEqual(cache["c"], 3)
    }
}
