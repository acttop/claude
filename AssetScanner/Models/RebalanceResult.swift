import Foundation

struct RebalanceItem: Identifiable {
    let id: UUID
    let asset: PortfolioAsset
    let currentWeight: Double       // 현재 비중 %
    let targetWeight: Double        // 목표 비중 %
    let deviation: Double           // 이탈도 (현재 - 목표), + = 초과
    let currentValueKRW: Double     // 현재 금액 (원)
    let targetValueKRW: Double      // 목표 금액 (원)
    let recommendedBuyKRW: Double   // 권장 매수 금액 (원)
    let recommendedQuantity: Double // 권장 매수 수량

    var isOverweight: Bool { deviation > 1.0 }
    var isUnderweight: Bool { deviation < -1.0 }
    var isBalanced: Bool { !isOverweight && !isUnderweight }

    var statusLabel: String {
        if isOverweight { return "초과" }
        if isUnderweight { return "부족" }
        return "균형"
    }
}

struct ExchangeRateSnapshot {
    let rate: Double
    let fetchedAt: Date

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 3600
    }

    var formattedRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: NSNumber(value: rate)) ?? "0") + "원"
    }
}
