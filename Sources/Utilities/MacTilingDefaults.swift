/// MacTilingDefaults.swift

import Foundation

/// Read / disable the user defaults values for the macOS built-in window tiling, added in macOS 15 Sequoia.
/// These are toggled in the Desktop & Dock System Settings Pane:
enum MacTilingDefaults: String {
    case tilingByEdgeDrag = "EnableTilingByEdgeDrag"
    case tilingOptionAccelerator = "EnableTilingOptionAccelerator"
    case tiledWindowMargins = "EnableTiledWindowMargins"
    case topTilingByEdgeDrag = "EnableTopTilingByEdgeDrag"
    
    var enabled: Bool {
        guard #available(macOS 15, *), let defaults = UserDefaults(suiteName: "com.apple.WindowManager")
        else {
            return false
        }
        
        if defaults.object(forKey: self.rawValue) == nil { // These are enabled by default
            return true
        }
        return defaults.bool(forKey: self.rawValue)
    }
    
    func disable() {
        guard let defaults = UserDefaults(suiteName: "com.apple.WindowManager")
        else {
            return
        }
        
        defaults.set(false, forKey: self.rawValue)
        defaults.synchronize()
    }
    
    static func openSystemSettings() {
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.Desktop-Settings.extension")!)
    }
    
    static func checkForBuiltInTiling(skipIfAlreadyNotified: Bool) {
        guard #available(macOS 15, *), !RawmDefaults.windowSnapping.userDisabled
        else { return }

        let isStandardTilingConflicting = (tilingByEdgeDrag.enabled || tilingOptionAccelerator.enabled)
        
        let shouldSkipStandardCheck = skipIfAlreadyNotified && RawmDefaults.internalTilingNotified.enabled
        
        if isStandardTilingConflicting && !shouldSkipStandardCheck {
            resolveStandardTilingConflict()
        } else if isTopTilingConflicting {
            resolveTopTilingConflict()
        }
        RawmDefaults.internalTilingNotified.enabled = true
    }
    
    private static func resolveTopTilingConflict() {
        RawmLogger.log("Automatically disabling macOS top edge tiling to resolve conflict with macOS.")
        
        topTilingByEdgeDrag.disable()
        
        if !RawmDefaults.internalTilingNotified.enabled {
            // First time running rawm & only has drag to top enabled in macOS
            let result = AlertUtil.twoButtonAlert(
                question: "Top screen edge tiling in macOS is now disabled".localized,
                text: "To adjust macOS tiling, go to System Settings → Desktop & Dock → Windows".localized,
                cancelText: "Open System Settings".localized)
            if result == .alertSecondButtonReturn {
                openSystemSettings()
            }
        }
    }
    
    private static var isTopTilingConflicting: Bool {
        guard #available(macOS 15.1, *) else { return false }
        return topTilingByEdgeDrag.enabled && SnapAreaModel.instance.isTopConfigured
    }
    
    private static func resolveStandardTilingConflict() {
        let result = AlertUtil.threeButtonAlert(
            question: "Conflict with macOS tiling".localized,
            text: "Drag to screen edge tiling is enabled in both rawm and macOS.".localized,
            buttonOneText: "Disable in macOS".localized,
            buttonTwoText: "Disable in rawm".localized,
            buttonThreeText: "Dismiss".localized)
        switch result {
        case .alertFirstButtonReturn:
            disableMacTiling()

            let result = AlertUtil.twoButtonAlert(
                question: "Tiling in macOS has been disabled".localized,
                text: "To re-enable it, go to System Settings → Desktop & Dock → Windows".localized,
                cancelText: "Open System Settings".localized)
            if result == .alertSecondButtonReturn {
                openSystemSettings()
            }
        case .alertSecondButtonReturn:
            RawmDefaults.windowSnapping.enabled = false
            Notification.Name.windowSnapping.post(object: false)

            let result = AlertUtil.twoButtonAlert(
                question: "Tiling in rawm has been disabled".localized,
                text: "To adjust macOS tiling, go to System Settings → Desktop & Dock → Windows".localized,
                cancelText: "Open System Settings".localized)
            if result == .alertSecondButtonReturn {
                openSystemSettings()
            }
        default:
            break
        }
    }
    
    private static func disableMacTiling() {
        tilingByEdgeDrag.disable()
        tilingOptionAccelerator.disable()
        topTilingByEdgeDrag.disable()
    }
}
