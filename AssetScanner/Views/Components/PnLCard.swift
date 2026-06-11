import SwiftUI

struct PnLCard: View {
    let title: String
    let subtitle: String
    let amount: Double
    let percent: Double

    // 한국 주식 관례: 수익 = 빨간색, 손실 = 파란색
    private var color: Color { amount >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9) }
    private var sign: String { amount >= 0 ? "+" : "" }
    private var arrowIcon: String { amount >= 0 ? "arrow.up.right" : "arrow.down.right" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(sign + amount.formattedKRW())
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 3) {
                Image(systemName: arrowIcon)
                    .font(.caption2.weight(.semibold))
                Text(sign + String(format: "%.2f%%", percent))
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
