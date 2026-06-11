import SwiftUI

struct AllocationRowView: View {
    let asset: PortfolioAsset
    let currentWeight: Double
    let deviation: Double

    private var deviationColor: Color {
        if abs(deviation) <= 1.0 { return .green }
        return deviation > 0 ? .orange : Color(red: 0.1, green: 0.3, blue: 0.9)
    }

    private var statusIcon: String {
        if abs(deviation) <= 1.0 { return "checkmark.circle.fill" }
        return deviation > 1.0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var deviationText: String {
        String(format: "%+.1f%%", deviation)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // 종목 정보
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: statusIcon)
                            .font(.caption)
                            .foregroundStyle(deviationColor)
                        Text(asset.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    HStack(spacing: 4) {
                        Text(asset.currency.rawValue)
                        if !asset.symbol.isEmpty {
                            Text("·")
                            Text(asset.symbol)
                        }
                        if !asset.category.isEmpty {
                            Text("·")
                            Text(asset.category)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // 비중 수치
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 3) {
                        Text(String(format: "%.1f%%", currentWeight))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(deviationColor)
                        Text("/")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.0f%%", asset.targetWeight))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("이탈 " + deviationText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(deviationColor)
                }
            }

            // 비중 시각화 바
            AllocationBarView(currentWeight: currentWeight, targetWeight: asset.targetWeight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
