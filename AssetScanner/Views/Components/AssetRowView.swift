import SwiftUI

struct AssetRowView: View {
    let asset: AssetEntry

    private var color: Color { asset.pnl >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9) }
    private var sign: String { asset.pnl >= 0 ? "+" : "" }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 종목 심볼 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Text(String(asset.name.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(asset.quantity.formattedQuantity())주 · 매입 \(asset.averagePrice.formattedKRW())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(asset.currentValue.formattedKRW())
                    .font(.subheadline.weight(.semibold))
                Text(sign + String(format: "%.2f%%", asset.pnlPercent))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
