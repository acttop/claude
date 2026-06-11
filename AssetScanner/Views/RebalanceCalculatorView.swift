import SwiftUI

struct RebalanceCalculatorView: View {
    @EnvironmentObject var rbVM: RebalancingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var investmentStr = ""
    @State private var results: [RebalanceItem] = []
    @State private var hasCalculated = false

    private func num(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ""))
    }
    private var investment: Double { num(investmentStr) ?? 0 }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    inputCard
                    if hasCalculated { resultsCard }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("리밸런싱 계산")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 16) {
            // 현재 포트폴리오 요약
            HStack {
                infoBlock(label: "현재 총 자산", value: rbVM.totalValueKRW.formattedKRW())
                Spacer()
                infoBlock(label: "USD/KRW",
                          value: rbVM.rateService.snapshot?.formattedRate ?? "조회 필요",
                          align: .trailing)
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 추가 투자금 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("추가 투자금액")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    TextField("예: 500000", text: $investmentStr)
                        .keyboardType(.numberPad)
                        .font(.title3.weight(.medium))
                        .padding(12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("원")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // 빠른 금액 선택
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([100_000.0, 300_000.0, 500_000.0, 1_000_000.0, 3_000_000.0], id: \.self) { amount in
                        Button(amount.formattedChartKRW() + "원") {
                            investmentStr = String(Int(amount))
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(investment == amount ? Color.blue : Color(.tertiarySystemBackground))
                        .foregroundStyle(investment == amount ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 2)
            }

            // 계산 버튼
            Button {
                rbVM.calculate(additionalKRW: investment)
                results = rbVM.rebalanceResults
                hasCalculated = true
            } label: {
                Label("리밸런싱 계산", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(investment <= 0)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Results Card

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("매수 권고 결과")
                    .font(.headline)
                Text("추가 투자금 \(investment.formattedKRW()) 기준 · \(rbVM.rateService.snapshot != nil ? "환율 적용" : "환율 기본값 적용")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // 종목별 결과
            VStack(spacing: 0) {
                ForEach(results) { item in
                    RebalanceResultRow(item: item, rate: rbVM.rate)
                    if item.id != results.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal)

            // 합계 요약
            summaryCard
        }
    }

    private var summaryCard: some View {
        let actualBuy = results.reduce(0) { $0 + $1.recommendedBuyKRW }
        let remaining = investment - actualBuy
        let newTotal = rbVM.totalValueKRW + actualBuy

        return VStack(spacing: 0) {
            summaryRow("총 매수 금액", actualBuy.formattedKRW(), .primary, bold: true)
            Divider().padding(.horizontal)
            summaryRow("잔여 현금 (단주 미매수분)", remaining.formattedKRW(), .secondary)
            Divider().padding(.horizontal)
            summaryRow("매수 후 총 자산", newTotal.formattedKRW(), .blue, bold: true)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func infoBlock(label: String, value: String, align: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: align, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func summaryRow(_ label: String, _ value: String, _ color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value).font(bold ? .subheadline.weight(.bold) : .subheadline).foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
