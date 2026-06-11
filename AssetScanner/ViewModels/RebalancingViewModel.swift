import Foundation
import Combine

class RebalancingViewModel: ObservableObject {
    @Published var portfolio: Portfolio = Portfolio()
    @Published var rebalanceResults: [RebalanceItem] = []

    let rateService = ExchangeRateService()
    private let persistence = PersistenceService()
    private var cancellables = Set<AnyCancellable>()

    var rate: Double { rateService.snapshot?.rate ?? 1350.0 }
    var totalValueKRW: Double { portfolio.totalValueInKRW(rate: rate) }
    var needsRebalancing: Bool { RebalancingCalculator.needsRebalancing(portfolio: portfolio, rate: rate) }
    var maxDeviation: Double { RebalancingCalculator.maxDeviation(portfolio: portfolio, rate: rate) }

    init() {
        portfolio = persistence.loadPortfolio() ?? Portfolio()
        if portfolio.assets.isEmpty { loadSamplePortfolio() }

        // ExchangeRateService 변경을 이 ViewModel 변경으로 전파
        rateService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        Task { await rateService.fetchRate() }
    }

    // MARK: - Per-asset helpers
    func currentWeight(for asset: PortfolioAsset) -> Double {
        portfolio.currentWeight(for: asset.id, rate: rate)
    }

    func deviation(for asset: PortfolioAsset) -> Double {
        portfolio.deviation(for: asset.id, rate: rate)
    }

    // MARK: - Portfolio CRUD
    func addAsset(_ asset: PortfolioAsset) {
        portfolio.assets.append(asset)
        portfolio.lastUpdated = Date()
        save()
    }

    func updateAsset(_ asset: PortfolioAsset) {
        guard let idx = portfolio.assets.firstIndex(where: { $0.id == asset.id }) else { return }
        portfolio.assets[idx] = asset
        portfolio.lastUpdated = Date()
        save()
    }

    func deleteAssets(at offsets: IndexSet) {
        portfolio.assets.remove(atOffsets: offsets)
        save()
    }

    func updatePortfolioName(_ name: String) {
        portfolio.name = name
        save()
    }

    // MARK: - Rebalancing Calculation
    func calculate(additionalKRW: Double) {
        rebalanceResults = RebalancingCalculator.calculate(
            portfolio: portfolio, additionalKRW: additionalKRW, rate: rate)
    }

    // MARK: - Persistence
    private func save() { persistence.savePortfolio(portfolio) }

    // MARK: - 샘플 포트폴리오 (연금/ETF)
    private func loadSamplePortfolio() {
        portfolio = Portfolio(
            name: "연금 포트폴리오",
            assets: [
                PortfolioAsset(name: "TIGER 미국S&P500", symbol: "379800",
                               currency: .krw, targetWeight: 40,
                               currentPrice: 16800, quantity: 150, category: "해외주식"),
                PortfolioAsset(name: "TIGER 나스닥100", symbol: "133690",
                               currency: .krw, targetWeight: 25,
                               currentPrice: 84500, quantity: 25, category: "해외주식"),
                PortfolioAsset(name: "TIGER 국채10년", symbol: "148070",
                               currency: .krw, targetWeight: 20,
                               currentPrice: 48200, quantity: 35, category: "채권"),
                PortfolioAsset(name: "KODEX 골드선물", symbol: "132030",
                               currency: .krw, targetWeight: 10,
                               currentPrice: 14300, quantity: 40, category: "금"),
                PortfolioAsset(name: "TIGER 현금성자산", symbol: "190620",
                               currency: .krw, targetWeight: 5,
                               currentPrice: 100150, quantity: 5, category: "현금")
            ]
        )
        save()
    }
}
