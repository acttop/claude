import SwiftUI

struct RebalanceResultRow: View {
    let item: RebalanceItem
    let rate: Double

    private var deviationColor: Color {
        if item.isBalanced { return .green }
        return item.isOverweight ? .orange : Color(red: 0.1, green: 0.3, blue: 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // 종목명 + 현재→목표 비중
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.asset.name)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 5) {
                        Text(String(format: "%.1f%%", item.currentWeight))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(deviationColor)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", item.targetWeight))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "(%+.1f%%)", item.deviation))
                            .font(.caption)
                            .foregroundStyle(deviationColor)
                    }
                }

                Spacer()

                // 매수 권고
                VStack(alignment: .trailing, spacing: 3) {
                    if item.recommendedBuyKRW > 0 {
                        Text("+" + item.recommendedBuyKRW.formattedKRW())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                        if item.recommendedQuantity > 0 {
                            Text("\(item.recommendedQuantity.formattedQuantity())주 매수")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(item.isOverweight ? "초과보유" : "균형")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.isOverweight ? .orange : .green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((item.isOverweight ? Color.orange : Color.green).opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            // 이탈도 시각화
            HStack(spacing: 8) {
                Text("비중")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
                AllocationBarView(currentWeight: item.currentWeight, targetWeight: item.targetWeight)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
