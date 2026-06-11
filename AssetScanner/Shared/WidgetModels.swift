import Foundation

// 앱 ↔ 위젯 공유 데이터 모델 (App Group UserDefaults 경유)

struct AssetWidgetData: Codable {
    let totalValue: Double
    let totalInvestment: Double
    let dailyPnL: Double
    let dailyPnLPercent: Double
    let cumulativePnL: Double
    let cumulativePnLPercent: Double
    let topHoldings: [HoldingItem]
    let updatedAt: Date

    struct HoldingItem: Codable, Identifiable {
        var id: String { name }
        let name: String
        let value: Double
        let pnlPercent: Double
    }

    static let placeholder = AssetWidgetData(
        totalValue: 9_392_250,
        totalInvestment: 8_962_250,
        dailyPnL: 218_500,
        dailyPnLPercent: 2.38,
        cumulativePnL: 430_000,
        cumulativePnLPercent: 4.80,
        topHoldings: [
            .init(name: "TIGER 미국S&P500", value: 2_520_000, pnlPercent: 4.17),
            .init(name: "TIGER 나스닥100",  value: 2_112_500, pnlPercent: 6.13),
            .init(name: "TIGER 국채10년",   value: 1_687_000, pnlPercent: -0.52)
        ],
        updatedAt: Date()
    )
}

struct PortfolioWidgetData: Codable {
    let usdKrw: Double
    let needsRebalancing: Bool
    let maxDeviation: Double
    let portfolioName: String
    let updatedAt: Date

    static let placeholder = PortfolioWidgetData(
        usdKrw: 1350.0,
        needsRebalancing: true,
        maxDeviation: 5.9,
        portfolioName: "연금 포트폴리오",
        updatedAt: Date()
    )
}
