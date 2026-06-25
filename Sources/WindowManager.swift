/// WindowManager.swift

import Cocoa

class WindowManager {
    
    private let screenDetection = ScreenDetection()
    private let standardWindowMoverChain: [WindowMover]
    private let fixedSizeWindowMoverChain: [WindowMover]
    
    init() {
        standardWindowMoverChain = [
            StandardWindowMover(),
            EdgeAlignmentWindowMover(),
            BestEffortWindowMover()
        ]
        
        fixedSizeWindowMoverChain = [
            FixedSizeWindowMover(),
            BestEffortWindowMover()
        ]
    }
    
    private func recordAction(windowId: CGWindowID, resultingRect: CGRect, action: WindowAction, subAction: SubWindowAction?) {
        let newCount: Int
        if let lastRawmAction = AppDelegate.windowHistory.lastRawmActions[windowId], lastRawmAction.action == action {
            newCount = lastRawmAction.count + 1
        } else {
            newCount = 1
        }
        
        AppDelegate.windowHistory.lastRawmActions[windowId] = RawmAction(
            action: action,
            subAction: subAction,
            rect: resultingRect,
            count: newCount
        )
    }
    
    func execute(_ parameters: ExecutionParameters) {
        guard let frontmostWindowElement = parameters.windowElement ?? AccessibilityElement.getFrontWindowElement(),
              let windowId = parameters.windowId ?? frontmostWindowElement.getWindowId()
        else {
            NSSound.beep()
            return
        }
        
        let action = parameters.action
        
        if action == .restore {
            if let restoreRect = AppDelegate.windowHistory.restoreRects[windowId] {
                frontmostWindowElement.setFrame(restoreRect)
            }
            AppDelegate.windowHistory.lastRawmActions.removeValue(forKey: windowId)
            return
        }
        
        var screens: UsableScreens?
        if let screen = parameters.screen {
            screens = UsableScreens(currentScreen: screen, numScreens: 1)
        } else {
            screens = RawmDefaults.useCursorScreenDetection.enabled
            ? screenDetection.detectScreensAtCursor()
            : screenDetection.detectScreens(using: frontmostWindowElement)
        }
        
        guard let usableScreens = screens else {
            NSSound.beep()
            RawmLogger.log("Unable to obtain usable screens")
            return
        }
        
        let currentWindowRect: CGRect = frontmostWindowElement.frame
        
        var lastRawmAction = AppDelegate.windowHistory.lastRawmActions[windowId]
        
        let windowMovedExternally = currentWindowRect != lastRawmAction?.rect
        
        if windowMovedExternally {
            lastRawmAction = nil
            AppDelegate.windowHistory.lastRawmActions.removeValue(forKey: windowId)
        }
        
        if parameters.updateRestoreRect {
            if AppDelegate.windowHistory.restoreRects[windowId] == nil
                || windowMovedExternally {
                AppDelegate.windowHistory.restoreRects[windowId] = currentWindowRect
            }
        }
        
        let ignoreTodo = TodoManager.isTodoWindow(windowId)
        
        if frontmostWindowElement.isSheet == true
            || currentWindowRect.isNull
            || usableScreens.frameOfCurrentScreen.isNull
            || usableScreens.currentScreen.adjustedVisibleFrame(ignoreTodo).isNull {
            NSSound.beep()
            RawmLogger.log("Window is not snappable or usable screen is not valid")
            return
        }
        
        let currentNormalizedRect = currentWindowRect.screenFlipped
        let currentWindow = Window(id: windowId, rect: currentNormalizedRect)
        
        let windowCalculation = WindowCalculationFactory.calculationsByAction[action]
        
        let calculationParams = WindowCalculationParameters(window: currentWindow, usableScreens: usableScreens, action: action, lastAction: lastRawmAction, ignoreTodo: ignoreTodo)
        guard var calcResult = windowCalculation?.calculate(calculationParams) else {
            NSSound.beep()
            RawmLogger.log("Nil calculation result")
            return
        }
        
        let gapsApplicable = calcResult.resultingAction.gapsApplicable
        
        if RawmDefaults.gapSize.value > 0, gapsApplicable != .none {
            let gapSharedEdges = calcResult.resultingSubAction?.gapSharedEdge ?? calcResult.resultingAction.gapSharedEdge
            
            calcResult.rect = GapCalculation.applyGaps(calcResult.rect, dimension: gapsApplicable, sharedEdges: gapSharedEdges, gapSize: RawmDefaults.gapSize.value, skipTopGap: RawmDefaults.skipGapTopEdge.enabled)
        }

        if RawmDefaults.cyclingOverlapOffset.userEnabled, action.positionCycles {
            calcResult.rect = applyOverlapOffsetIfNeeded(calcResult.rect, windowId: windowId, screen: calcResult.screen)
        }

        if currentNormalizedRect.equalTo(calcResult.rect) {
            RawmLogger.log("Current frame is equal to new frame")

            recordAction(windowId: windowId, resultingRect: currentWindowRect, action: calcResult.resultingAction, subAction: calcResult.resultingSubAction)

            return
        }
        
        let visibleFrameOfDestinationScreen = calcResult.resultingScreenFrame ?? calcResult.screen.adjustedVisibleFrame(ignoreTodo)
        let isFixedSize = (!frontmostWindowElement.isResizable() && action.resizes) || frontmostWindowElement.isSystemDialog == true
        let resultParameters = ResultParameters(windowId: windowId,
                                                action: action,
                                                windowElement: frontmostWindowElement,
                                                calcResult: calcResult,
                                                usableScreens: usableScreens,
                                                visibleFrameOfScreen: visibleFrameOfDestinationScreen,
                                                source: parameters.source,
                                                isFixedSize: isFixedSize)
        
        var resultingRect = apply(result: resultParameters)
        
        let isMovedAcrossDisplays = usableScreens.currentScreen != calcResult.screen
        if isMovedAcrossDisplays {
            if calcResult.rect.height != resultingRect.height {
                RawmLogger.log("Window size wasn't applied perfectly across displays. Trying again.")
                resultingRect = apply(result: resultParameters)
                
                if calcResult.rect.height != resultingRect.height {
                    RawmLogger.log("Final attempt to adjust across displays.")
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(25)) { [weak self] in
                        guard let self else { return }
                        let finalRect = self.apply(result: resultParameters)
                        self.windowMovedAcrossDisplays(windowElement: frontmostWindowElement, resultingRect: finalRect)
                        self.postProcess(result: resultParameters, resultingRect: finalRect)
                    }
                    return
                }
            }
            windowMovedAcrossDisplays(windowElement: frontmostWindowElement, resultingRect: resultingRect)
        }
        
        postProcess(result: resultParameters, resultingRect: resultingRect)
    }
    
    /// Move/resize a window based on the calculation results.
    /// - Returns: The rect of the window after applying the window action
    func apply(result: ResultParameters) -> CGRect {
        let windowMoverChain = result.isFixedSize
        ? fixedSizeWindowMoverChain
        : standardWindowMoverChain
        
        let newRect = result.calcResult.rect
        
        for windowMover in windowMoverChain {
            windowMover.moveWindow(toRect: newRect, resultParameters: result)
        }
        
        return result.windowElement.frame
    }
    
    func windowMovedAcrossDisplays(windowElement: AccessibilityElement, resultingRect: CGRect) {
        windowElement.bringToFront(force: true)
        
        if RawmDefaults.moveCursorAcrossDisplays.userEnabled {
            CGWarpMouseCursorPosition(resultingRect.centerPoint)
        }
    }
    
    private func applyOverlapOffsetIfNeeded(_ rect: CGRect, windowId: CGWindowID, screen: NSScreen) -> CGRect {
        let overlapOffset = CGFloat(RawmDefaults.cyclingOverlapOffsetSize.value)
        guard overlapOffset > 0 else { return rect }

        let screenFrameAX = screen.adjustedVisibleFrame().screenFlipped
        let tolerance: CGFloat = 4
        let maxCascade = min(5, max(1, RawmDefaults.cyclingOverlapMaxCascade.value))

        let otherWindows = AccessibilityElement.getAllWindowElements().filter { element in
            guard element.getWindowId() != windowId,
                  element.isWindow == true,
                  element.isMinimized != true,
                  element.isHidden != true,
                  element.isSheet != true
            else { return false }

            let frame = element.frame
            return !frame.isNull && screenFrameAX.intersects(frame)
        }

        let screenFrameNormalized = screen.adjustedVisibleFrame()
        var candidate = rect
        var cascadeLevel = 0

        while cascadeLevel < maxCascade {
            let candidateAX = candidate.screenFlipped
            let hasOverlap = otherWindows.contains { element in
                let otherFrame = element.frame
                let originsMatch = abs(otherFrame.origin.x - candidateAX.origin.x) < tolerance
                    && abs(otherFrame.origin.y - candidateAX.origin.y) < tolerance
                let otherCoversScreen = otherFrame.width > screenFrameAX.width * 0.9
                    && otherFrame.height > screenFrameAX.height * 0.9
                return originsMatch && !otherCoversScreen
            }

            guard hasOverlap else { break }

            candidate.origin.x += overlapOffset
            candidate.origin.y += overlapOffset
            cascadeLevel += 1

            if candidate.origin.x + candidate.width > screenFrameNormalized.maxX {
                candidate.origin.x = screenFrameNormalized.maxX - candidate.width
            }
            if candidate.origin.y + candidate.height > screenFrameNormalized.maxY {
                candidate.origin.y = screenFrameNormalized.maxY - candidate.height
            }
            if candidate.origin.x < screenFrameNormalized.origin.x {
                candidate.origin.x = screenFrameNormalized.origin.x
            }
            if candidate.origin.y < screenFrameNormalized.origin.y {
                candidate.origin.y = screenFrameNormalized.origin.y
            }
        }

        if cascadeLevel > 0 {
            RawmLogger.log("Cycling overlap detected, applied \(cascadeLevel) x \(overlapOffset)pt cascade offset")
        }
        return candidate
    }

    func postProcess(result: ResultParameters, resultingRect: CGRect) {
        let calcResult = result.calcResult
        
        if RawmDefaults.moveCursor.userEnabled, result.source == .keyboardShortcut {
            CGWarpMouseCursorPosition(resultingRect.centerPoint)
        }
        
        recordAction(windowId: result.windowId, resultingRect: resultingRect, action: calcResult.resultingAction, subAction: calcResult.resultingSubAction)
        
        if RawmLogger.logging {
            var logItems = ["\(result.action.name)",
                            "display: \(result.visibleFrameOfScreen.debugDescription)",
                            "calculatedRect: \(result.calcResult.rect.screenFlipped.debugDescription)",
                            "resultRect: \(resultingRect.debugDescription)",
                            "srcScreen: \(result.usableScreens.currentScreen.localizedName)",
                            "destScreen: \(calcResult.screen.localizedName)"]
            if let resultScreens = screenDetection.detectScreens(using: result.windowElement) {
                logItems.append("resultScreen: \(resultScreens.currentScreen.localizedName)")
            }
            RawmLogger.log(logItems.joined(separator: ", "))
        }
    }
}

struct ResultParameters {
    let windowId: CGWindowID
    let action: WindowAction
    let windowElement: AccessibilityElement
    let calcResult: WindowCalculationResult
    let usableScreens: UsableScreens
    let visibleFrameOfScreen: CGRect
    let source: ExecutionSource
    let isFixedSize: Bool
}

struct RawmAction {
    let action: WindowAction
    let subAction: SubWindowAction?
    let rect: CGRect
    let count: Int
}

struct ExecutionParameters {
    let action: WindowAction
    let updateRestoreRect: Bool
    let screen: NSScreen?
    let windowElement: AccessibilityElement?
    let windowId: CGWindowID?
    let source: ExecutionSource

    init(_ action: WindowAction, updateRestoreRect: Bool = true, screen: NSScreen? = nil, windowElement: AccessibilityElement? = nil, windowId: CGWindowID? = nil, source: ExecutionSource = .keyboardShortcut) {
        self.action = action
        self.updateRestoreRect = updateRestoreRect
        self.screen = screen
        self.windowElement = windowElement
        self.windowId = windowId
        self.source = source
    }
}

enum ExecutionSource {
    case keyboardShortcut, dragToSnap, menuItem, url, titleBar
}
