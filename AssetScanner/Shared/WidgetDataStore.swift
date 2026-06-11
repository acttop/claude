import Foundation

// App Group을 통해 앱 ↔ 위젯 데이터 공유
// Xcode에서 두 타겟 모두 "group.com.assetscanner.app" App Group 활성화 필요
struct WidgetDataStore {
    static let appGroupID = "group.com.assetscanner.app"

    private static let assetKey = "widget_asset_data"
    private static let portfolioKey = "widget_portfolio_data"

    private static var shared: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - 자산 현황 (AssetViewModel → Widget)

    static func saveAssetData(_ data: AssetWidgetData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        shared?.set(encoded, forKey: assetKey)
    }

    static func loadAssetData() -> AssetWidgetData? {
        guard let raw = shared?.data(forKey: assetKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AssetWidgetData.self, from: raw)
    }

    // MARK: - 포트폴리오 (RebalancingViewModel → Widget)

    static func savePortfolioData(_ data: PortfolioWidgetData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        shared?.set(encoded, forKey: portfolioKey)
    }

    static func loadPortfolioData() -> PortfolioWidgetData? {
        guard let raw = shared?.data(forKey: portfolioKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PortfolioWidgetData.self, from: raw)
    }
}
