import SwiftUI

struct RecordDetailView: View {
    @EnvironmentObject var vm: AssetViewModel
    @Environment(\.dismiss) private var dismiss
    let record: ScanRecord

    private var daily: Double { vm.dailyPnL(for: record) }
    private var dailyPct: Double { vm.dailyPnLPercent(for: record) }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 EEEE"
        return f
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    // 날짜 헤더
                    VStack(spacing: 6) {
                        Text(dateFormatter.string(from: record.date))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(record.totalValue.formattedKRW())
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("총 평가금액")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // P&L 카드
                    HStack(spacing: 12) {
                        PnLCard(title: "일별 손익", subtitle: "전일 대비",
                                amount: daily, percent: dailyPct)
                        PnLCard(title: "누적 손익", subtitle: "매입가 대비",
                                amount: record.totalPnL, percent: record.totalPnLPercent)
                    }
                    .padding(.horizontal)

                    // 보유 종목
                    if !record.assets.isEmpty {
                        holdingsSection
                    }

                    // 요약 테이블
                    summarySection
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("상세 내역")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("보유 종목")
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(record.assets) { asset in
                    AssetRowView(asset: asset)
                    if asset.id != record.assets.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .padding(.horizontal)
        }
    }

    private var summarySection: some View {
        VStack(spacing: 0) {
            summaryRow("총 매입금액", record.totalInvestment.formattedKRW(), .primary)
            Divider().padding(.horizontal)
            summaryRow("총 평가금액", record.totalValue.formattedKRW(), .primary)
            Divider().padding(.horizontal)
            summaryRow(
                "누적 손익",
                record.totalPnL.signedPrefix + record.totalPnL.formattedKRW()
                    + " (\(record.totalPnLPercent.signedPrefix)\(String(format: "%.2f%%", record.totalPnLPercent)))",
                record.totalPnL >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9),
                bold: true
            )
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal)
    }

    private func summaryRow(_ label: String, _ value: String, _ color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(bold ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}
