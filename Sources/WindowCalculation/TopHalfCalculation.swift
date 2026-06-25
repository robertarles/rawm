/// TopHalfCalculation.swift

import Foundation

class TopHalfCalculation: WindowCalculation, RepeatedExecutionsInThirdsCalculation {

    override func calculateRect(_ params: RectCalculationParameters) -> RectResult {

        if params.lastAction == nil || !RawmDefaults.subsequentExecutionMode.resizes {
            return calculateFirstRect(params)
        }
        
        return calculateRepeatedRect(params)
    }
    
    func calculateFirstRect(_ params: RectCalculationParameters) -> RectResult {
        return RectResult(HalfSplitFrameCalculation.verticalRect(in: params.visibleFrameOfScreen, side: .leading, fraction: RawmDefaults.verticalSplitRatio.value / 100.0))
    }

    func calculateFractionalRect(_ params: RectCalculationParameters, fraction: Float) -> RectResult {
        return RectResult(HalfSplitFrameCalculation.verticalRect(in: params.visibleFrameOfScreen, side: .leading, fraction: fraction))
    }
    
}
