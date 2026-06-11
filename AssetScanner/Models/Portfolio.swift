import Foundation

struct Portfolio: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = "내 포트폴리오"
    var assets: [PortfolioAsset] = []
    var lastUpdated: Date = Date()

    var totalTargetWeight: Double { assets.reduce(0) { $0 + $1.targetWeight } }
    var isWeightValid: Bool { abs(totalTargetWeight - 100.0) < 0.5 }
    var remainingWeight: Double { max(0, 100.0 - totalTargetWeight) }

    func totalValueInKRW(rate: Double) -> Double {
        assets.reduce(0) { $0 + $1.valueInKRW(rate: rate) }
    }

    func currentWeight(for assetId: UUID, rate: Double) -> Double {
        guard let asset = assets.first(where: { $0.id == assetId }) else { return 0 }
        let total = totalValueInKRW(rate: rate)
        guard total > 0 else { return 0 }
        return (asset.valueInKRW(rate: rate) / total) * 100
    }

    func deviation(for assetId: UUID, rate: Double) -> Double {
        guard let asset = assets.first(where: { $0.id == assetId }) else { return 0 }
        return currentWeight(for: assetId, rate: rate) - asset.targetWeight
    }
}
