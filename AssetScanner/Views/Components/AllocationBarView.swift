import SwiftUI

struct AllocationBarView: View {
    let currentWeight: Double
    let targetWeight: Double

    private var isOver: Bool { currentWeight > targetWeight + 1.0 }
    private var isUnder: Bool { currentWeight < targetWeight - 1.0 }

    private var barColor: Color {
        if isOver { return .orange }
        if isUnder { return Color(red: 0.1, green: 0.3, blue: 0.9) }
        return .green
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // scale: 최댓값을 목표비중의 1.6배로 고정해서 비율 비교 가능하게
            let maxW = max(targetWeight * 1.6, currentWeight + 2, 10)
            let curFrac = CGFloat(min(currentWeight / maxW, 1.0))
            let tgtFrac = CGFloat(min(targetWeight / maxW, 1.0))

            ZStack(alignment: .leading) {
                // 배경 트랙
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)

                // 현재 비중 바
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor.opacity(0.75))
                    .frame(width: w * curFrac, height: 6)

                // 목표 비중 마커 (수직선)
                Rectangle()
                    .fill(Color(.systemGray2))
                    .frame(width: 2, height: 14)
                    .offset(x: w * tgtFrac - 1, y: -4)
            }
        }
        .frame(height: 14)
    }
}
