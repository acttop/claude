import Foundation

struct ScanRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date
    var assets: [AssetEntry]
    var imageData: Data?
    var notes: String = ""

    var totalInvestment: Double { assets.reduce(0) { $0 + $1.investmentAmount } }
    var totalValue: Double { assets.reduce(0) { $0 + $1.currentValue } }
    var totalPnL: Double { totalValue - totalInvestment }
    var totalPnLPercent: Double {
        guard totalInvestment > 0 else { return 0 }
        return (totalPnL / totalInvestment) * 100
    }

    init(id: UUID = UUID(), date: Date = Date(), assets: [AssetEntry] = [],
         imageData: Data? = nil, notes: String = "") {
        self.id = id
        self.date = date
        self.assets = assets
        self.imageData = imageData
        self.notes = notes
    }
}
