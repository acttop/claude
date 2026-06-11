import Foundation
import SwiftUI
import WidgetKit

struct PnLDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let dailyPnL: Double
    let cumulativePnL: Double
}

class AssetViewModel: ObservableObject {
    @Published var scanRecords: [ScanRecord] = []

    private let persistence = PersistenceService()

    init() {
        loadRecords()
        if scanRecords.isEmpty { addSampleData() }
    }

    // MARK: - Sorted Records
    var sortedRecords: [ScanRecord] {
        scanRecords.sorted { $0.date > $1.date }
    }

    var latestRecord: ScanRecord? { sortedRecords.first }

    func record(before target: ScanRecord) -> ScanRecord? {
        let sorted = sortedRecords
        guard let idx = sorted.firstIndex(where: { $0.id == target.id }),
              idx + 1 < sorted.count else { return nil }
        return sorted[idx + 1]
    }

    // MARK: - P&L

    // 일별 손익: 전일 대비 평가금액 변화
    func dailyPnL(for record: ScanRecord) -> Double {
        guard let prev = self.record(before: record) else { return 0 }
        return record.totalValue - prev.totalValue
    }

    func dailyPnLPercent(for record: ScanRecord) -> Double {
        guard let prev = self.record(before: record), prev.totalValue > 0 else { return 0 }
        return (dailyPnL(for: record) / prev.totalValue) * 100
    }

    // 최신 일별 손익
    var latestDailyPnL: Double { latestRecord.map { dailyPnL(for: $0) } ?? 0 }
    var latestDailyPnLPercent: Double { latestRecord.map { dailyPnLPercent(for: $0) } ?? 0 }

    // 누적 손익: 매입금액 대비 현재 평가금액
    var cumulativePnL: Double { latestRecord?.totalPnL ?? 0 }
    var cumulativePnLPercent: Double { latestRecord?.totalPnLPercent ?? 0 }

    var totalValue: Double { latestRecord?.totalValue ?? 0 }
    var totalInvestment: Double { latestRecord?.totalInvestment ?? 0 }

    // MARK: - Chart Data
    var pnlChartData: [PnLDataPoint] {
        let sorted = Array(sortedRecords.reversed())
        return sorted.enumerated().map { i, record in
            let daily = i > 0 ? record.totalValue - sorted[i - 1].totalValue : 0
            return PnLDataPoint(date: record.date, dailyPnL: daily, cumulativePnL: record.totalPnL)
        }
    }

    // MARK: - CRUD
    func addRecord(_ record: ScanRecord) {
        scanRecords.append(record)
        save()
    }

    func updateRecord(_ record: ScanRecord) {
        if let idx = scanRecords.firstIndex(where: { $0.id == record.id }) {
            scanRecords[idx] = record
            save()
        }
    }

    func deleteRecords(at offsets: IndexSet) {
        let sorted = sortedRecords
        let toDelete = offsets.map { sorted[$0].id }
        scanRecords.removeAll { toDelete.contains($0.id) }
        save()
    }

    func deleteAllRecords() {
        scanRecords.removeAll()
        save()
    }

    private func save() {
        persistence.saveRecords(scanRecords)
        syncWidgetData()
    }

    private func loadRecords() { scanRecords = persistence.loadRecords() }

    // MARK: - Widget 동기화
    private func syncWidgetData() {
        let holdings = (latestRecord?.assets.prefix(3) ?? []).map {
            AssetWidgetData.HoldingItem(name: $0.name, value: $0.currentValue, pnlPercent: $0.pnlPercent)
        }
        let data = AssetWidgetData(
            totalValue: totalValue,
            totalInvestment: totalInvestment,
            dailyPnL: latestDailyPnL,
            dailyPnLPercent: latestDailyPnLPercent,
            cumulativePnL: cumulativePnL,
            cumulativePnLPercent: cumulativePnLPercent,
            topHoldings: Array(holdings),
            updatedAt: Date()
        )
        WidgetDataStore.saveAssetData(data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 샘플 데이터
    private func addSampleData() {
        let cal = Calendar.current
        let today = Date()

        let prices: [(Int, Double, Double, Double)] = [
            (-5, 68000, 130000, 192000),
            (-4, 71000, 135000, 195000),
            (-3, 72500, 138000, 197000),
            (-2, 71800, 136500, 198500),
            (-1, 73200, 140000, 201000),
            (0,  74500, 142000, 199000)
        ]

        scanRecords = prices.map { dayOffset, samsungPrice, skhynixPrice, naverPrice in
            let date = cal.date(byAdding: .day, value: dayOffset, to: today)!
            return ScanRecord(date: date, assets: [
                AssetEntry(name: "삼성전자", symbol: "005930", quantity: 10,
                           averagePrice: 70000, currentPrice: samsungPrice),
                AssetEntry(name: "SK하이닉스", symbol: "000660", quantity: 5,
                           averagePrice: 130000, currentPrice: skhynixPrice),
                AssetEntry(name: "NAVER", symbol: "035420", quantity: 3,
                           averagePrice: 200000, currentPrice: naverPrice)
            ])
        }
        save()
    }
}
