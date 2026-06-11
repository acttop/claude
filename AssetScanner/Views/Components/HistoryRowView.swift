import SwiftUI

struct HistoryRowView: View {
    let record: ScanRecord
    let dailyPnL: Double
    let dailyPnLPercent: Double

    private var dailyColor: Color { dailyPnL >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9) }
    private var cumulColor: Color { record.totalPnL >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9) }
    private var dSign: String { dailyPnL >= 0 ? "+" : "" }
    private var cSign: String { record.totalPnL >= 0 ? "+" : "" }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (EEE)"
        return f
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dateFormatter.string(from: record.date))
                        .font(.subheadline.weight(.semibold))
                    Text("종목 \(record.assets.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(record.totalValue.formattedKRW())
                        .font(.subheadline.weight(.bold))
                    Text("총 평가금액")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                pnlBlock(
                    label: "일별 손익",
                    amount: dSign + dailyPnL.formattedKRW(),
                    percent: dSign + String(format: "%.2f%%", dailyPnLPercent),
                    color: dailyColor,
                    align: .leading
                )
                Spacer()
                pnlBlock(
                    label: "누적 손익",
                    amount: cSign + record.totalPnL.formattedKRW(),
                    percent: cSign + String(format: "%.2f%%", record.totalPnLPercent),
                    color: cumulColor,
                    align: .trailing
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func pnlBlock(label: String, amount: String, percent: String,
                          color: Color, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(percent)
                .font(.caption2)
                .foregroundStyle(color)
        }
    }
}
