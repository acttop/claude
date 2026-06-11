import SwiftUI
import Charts

struct RebalancingView: View {
    @EnvironmentObject var rbVM: RebalancingViewModel
    @State private var showSetup = false
    @State private var showCalculator = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    // 환율 위젯
                    ExchangeRateWidget(rateService: rbVM.rateService)

                    // 포트폴리오 요약
                    portfolioSummaryCard

                    // 목표 비중 차트
                    if !rbVM.portfolio.assets.isEmpty {
                        allocationChartCard
                    }

                    // 종목별 비중 상세
                    if !rbVM.portfolio.assets.isEmpty {
                        allocationDetailCard
                    }

                    // 리밸런싱 계산 버튼
                    calculateButton
                }
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("리밸런싱")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSetup = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showSetup) {
                PortfolioSetupView().environmentObject(rbVM)
            }
            .sheet(isPresented: $showCalculator) {
                RebalanceCalculatorView().environmentObject(rbVM)
            }
        }
    }

    // MARK: - Portfolio Summary

    private var portfolioSummaryCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rbVM.portfolio.name)
                        .font(.headline)
                    Text("종목 \(rbVM.portfolio.assets.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(rbVM.totalValueKRW.formattedKRW())
                        .font(.title3.weight(.bold))
                    Text("총 평가금액")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: rbVM.needsRebalancing
                    ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(rbVM.needsRebalancing ? .orange : .green)

                Text(rbVM.needsRebalancing
                    ? String(format: "리밸런싱 권고 — 최대 이탈 %.1f%%", rbVM.maxDeviation)
                    : "목표 비중 균형")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(rbVM.needsRebalancing ? .orange : .green)

                Spacer()

                if rbVM.needsRebalancing {
                    Button("계산") { showCalculator = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Pie-like Chart (현재 비중 vs 목표 비중)

    private var allocationChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("비중 현황")
                .font(.headline)
                .padding(.horizontal)

            // 현재/목표 비중 비교 막대 차트
            Chart {
                ForEach(rbVM.portfolio.assets) { asset in
                    let current = rbVM.currentWeight(for: asset)
                    BarMark(
                        x: .value("비중", current),
                        y: .value("종목", asset.name)
                    )
                    .foregroundStyle(by: .value("유형", "현재"))
                    .annotation(position: .trailing) {
                        Text(String(format: "%.1f%%", current))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    BarMark(
                        x: .value("비중", asset.targetWeight),
                        y: .value("종목", asset.name)
                    )
                    .foregroundStyle(by: .value("유형", "목표"))
                }
            }
            .chartForegroundStyleScale([
                "현재": Color.blue.opacity(0.7),
                "목표": Color.gray.opacity(0.3)
            ])
            .chartLegend(position: .bottom)
            .frame(height: CGFloat(rbVM.portfolio.assets.count) * 44 + 40)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal)
        }
    }

    // MARK: - Allocation Detail

    private var allocationDetailCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("종목별 비중")
                    .font(.headline)
                Spacer()
                Text("현재 / 목표")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(rbVM.portfolio.assets) { asset in
                    AllocationRowView(
                        asset: asset,
                        currentWeight: rbVM.currentWeight(for: asset),
                        deviation: rbVM.deviation(for: asset)
                    )
                    if asset.id != rbVM.portfolio.assets.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal)
        }
    }

    // MARK: - CTA Button

    private var calculateButton: some View {
        Button { showCalculator = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("리밸런싱 계산")
                        .font(.headline)
                    Text("추가 투자금 → 매수 종목·수량 계산")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
    }
}
