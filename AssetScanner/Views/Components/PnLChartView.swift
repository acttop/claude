import SwiftUI
import Charts

struct PnLChartView: View {
    @EnvironmentObject var vm: AssetViewModel
    @State private var chartMode = 0  // 0: 일별, 1: 누적

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $chartMode) {
                Text("일별 손익").tag(0)
                Text("누적 손익").tag(1)
            }
            .pickerStyle(.segmented)

            if vm.pnlChartData.count < 2 {
                Text("데이터가 더 필요합니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 160)
            } else if chartMode == 0 {
                dailyChart
            } else {
                cumulativeChart
            }
        }
    }

    private var dailyChart: some View {
        Chart(vm.pnlChartData) { point in
            BarMark(
                x: .value("날짜", point.date, unit: .day),
                y: .value("일별 손익", point.dailyPnL)
            )
            .foregroundStyle(point.dailyPnL >= 0 ? Color.red : Color(red: 0.1, green: 0.3, blue: 0.9))
            .cornerRadius(4)
        }
        .chartYAxis { axisLabels }
        .chartXAxis { dateLabels }
        .frame(height: 160)
    }

    private var cumulativeChart: some View {
        Chart(vm.pnlChartData) { point in
            AreaMark(
                x: .value("날짜", point.date, unit: .day),
                y: .value("누적 손익", point.cumulativePnL)
            )
            .foregroundStyle(
                LinearGradient(colors: [.orange.opacity(0.3), .orange.opacity(0.05)],
                               startPoint: .top, endPoint: .bottom)
            )
            LineMark(
                x: .value("날짜", point.date, unit: .day),
                y: .value("누적 손익", point.cumulativePnL)
            )
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .symbol(Circle().strokeBorder(lineWidth: 2))
            .symbolSize(24)
        }
        .chartYAxis { axisLabels }
        .chartXAxis { dateLabels }
        .frame(height: 160)
    }

    private var axisLabels: some AxisContent {
        AxisMarks { value in
            AxisGridLine(stroke: StrokeStyle(dash: [3]))
                .foregroundStyle(Color(.separator).opacity(0.5))
            AxisValueLabel {
                if let v = value.as(Double.self) {
                    Text(v.formattedChartKRW())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dateLabels: some AxisContent {
        AxisMarks(values: .stride(by: .day)) { value in
            AxisValueLabel(format: .dateTime.month(.twoDigits).day(.twoDigits))
                .font(.caption2)
        }
    }
}
