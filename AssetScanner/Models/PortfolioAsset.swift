import Foundation

enum AssetCurrency: String, Codable, CaseIterable {
    case krw = "KRW"
    case usd = "USD"

    var displayName: String {
        switch self {
        case .krw: return "원화 (KRW)"
        case .usd: return "달러 (USD)"
        }
    }
    var symbol: String { self == .usd ? "$" : "₩" }
}

struct PortfolioAsset: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var symbol: String = ""
    var currency: AssetCurrency = .krw
    var targetWeight: Double        // 목표 비중 % (0~100)
    var currentPrice: Double        // 현재가 (해당 통화)
    var quantity: Double            // 보유수량
    var category: String = ""       // 자산군 분류

    var currentValue: Double { currentPrice * quantity }

    func valueInKRW(rate: Double) -> Double {
        currency == .usd ? currentValue * rate : currentValue
    }
    func priceInKRW(rate: Double) -> Double {
        currency == .usd ? currentPrice * rate : currentPrice
    }
}
