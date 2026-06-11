import Foundation

struct RebalancingCalculator {

    // 추가 투자금을 어떤 종목에 얼마나 매수해야 목표 비중에 가까워지는지 계산
    // 매도 없이 매수만으로 리밸런싱 (연금/ISA 계좌 최적화)
    static func calculate(
        portfolio: Portfolio,
        additionalKRW: Double,
        rate: Double
    ) -> [RebalanceItem] {
        guard !portfolio.assets.isEmpty else { return [] }

        let totalCurrentKRW = portfolio.totalValueInKRW(rate: rate)
        let newTotalKRW = totalCurrentKRW + additionalKRW

        struct Raw {
            let asset: PortfolioAsset
            let currentKRW: Double
            let targetKRW: Double
            let currentWeight: Double
            let deficit: Double   // > 0 이면 매수 필요
        }

        let rawData: [Raw] = portfolio.assets.map { asset in
            let curr = asset.valueInKRW(rate: rate)
            let target = newTotalKRW * asset.targetWeight / 100.0
            let weight = totalCurrentKRW > 0 ? (curr / totalCurrentKRW) * 100.0 : 0
            return Raw(asset: asset, currentKRW: curr, targetKRW: target,
                       currentWeight: weight, deficit: target - curr)
        }

        // 부족한 종목들에 비례 배분 (초과 종목은 0)
        let totalDeficit = rawData.filter { $0.deficit > 0 }.reduce(0) { $0 + $1.deficit }

        return rawData.map { r in
            var buyKRW: Double = 0
            if r.deficit > 0 {
                buyKRW = totalDeficit <= additionalKRW
                    ? r.deficit                                            // 전액 채움
                    : additionalKRW * (r.deficit / totalDeficit)          // 비례 배분
            }

            let priceKRW = r.asset.priceInKRW(rate: rate)
            let qty = priceKRW > 0 ? floor(buyKRW / priceKRW) : 0

            return RebalanceItem(
                id: r.asset.id,
                asset: r.asset,
                currentWeight: r.currentWeight,
                targetWeight: r.asset.targetWeight,
                deviation: r.currentWeight - r.asset.targetWeight,
                currentValueKRW: r.currentKRW,
                targetValueKRW: r.targetKRW,
                recommendedBuyKRW: qty * priceKRW,  // 실제 살 수 있는 금액 (수량 기준)
                recommendedQuantity: qty
            )
        }
    }

    // 이탈도 임계값(기본 5%) 이상이면 리밸런싱 권고
    static func needsRebalancing(portfolio: Portfolio, rate: Double, threshold: Double = 5.0) -> Bool {
        portfolio.assets.contains { asset in
            abs(portfolio.deviation(for: asset.id, rate: rate)) >= threshold
        }
    }

    static func maxDeviation(portfolio: Portfolio, rate: Double) -> Double {
        portfolio.assets.map { abs(portfolio.deviation(for: $0.id, rate: rate)) }.max() ?? 0
    }
}
