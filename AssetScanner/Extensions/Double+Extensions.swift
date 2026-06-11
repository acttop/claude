import Foundation

extension Double {
    func formattedKRW() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: abs(self))) ?? "0"
        return (self < 0 ? "-" : "") + formatted + "원"
    }

    func formattedChartKRW() -> String {
        let absValue = abs(self)
        let sign = self < 0 ? "-" : ""
        if absValue >= 100_000_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 100_000_000))억"
        } else if absValue >= 10_000 {
            return "\(sign)\(String(format: "%.0f", absValue / 10_000))만"
        } else {
            return "\(sign)\(String(format: "%.0f", absValue))"
        }
    }

    func formattedQuantity() -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }

    var signedPrefix: String { self >= 0 ? "+" : "" }
    var pnlColor: Bool { self >= 0 }  // true = red (profit), false = blue (loss)
}
