import Foundation

struct AssetEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var symbol: String = ""
    var quantity: Double
    var averagePrice: Double   // 매입단가
    var currentPrice: Double   // 현재가

    var investmentAmount: Double { quantity * averagePrice }  // 매입금액
    var currentValue: Double { quantity * currentPrice }      // 평가금액
    var pnl: Double { currentValue - investmentAmount }       // 평가손익
    var pnlPercent: Double {
        guard investmentAmount > 0 else { return 0 }
        return (pnl / investmentAmount) * 100
    }
}
