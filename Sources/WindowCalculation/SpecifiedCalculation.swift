import Foundation

final class SpecifiedCalculation: WindowCalculation {

    private let widthDefault: FloatDefault
    private let heightDefault: FloatDefault

    override init() {
        widthDefault  = RawmDefaults.specifiedWidth
        heightDefault = RawmDefaults.specifiedHeight
        super.init()
    }

    init(widthDefault: FloatDefault, heightDefault: FloatDefault) {
        self.widthDefault  = widthDefault
        self.heightDefault = heightDefault
        super.init()
    }

    override func calculateRect(_ params: RectCalculationParameters) -> RectResult {

        let visibleFrameOfScreen = params.visibleFrameOfScreen
        var calculatedWindowRect = visibleFrameOfScreen

        let rawH = CGFloat(heightDefault.value)
        let rawW = CGFloat(widthDefault.value)

        // Resize
        calculatedWindowRect.size.height = rawH <= 1
            ? visibleFrameOfScreen.height * rawH
            : round(rawH)
        calculatedWindowRect.size.width = rawW <= 1
            ? visibleFrameOfScreen.width * rawW
            : min(visibleFrameOfScreen.width, round(rawW))

        // Center
        calculatedWindowRect.origin.x = round((visibleFrameOfScreen.width  - calculatedWindowRect.width)  / 2.0) + visibleFrameOfScreen.minX
        calculatedWindowRect.origin.y = round((visibleFrameOfScreen.height - calculatedWindowRect.height) / 2.0) + visibleFrameOfScreen.minY

        return RectResult(calculatedWindowRect)
    }
}
