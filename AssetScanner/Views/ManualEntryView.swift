import SwiftUI

struct ManualEntryView: View {
    @EnvironmentObject var vm: AssetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var scanDate = Date()
    @State private var assets: [AssetEntry] = []
    @State private var showAddAsset = false

    private var totalInvestment: Double { assets.reduce(0) { $0 + $1.investmentAmount } }
    private var totalValue: Double { assets.reduce(0) { $0 + $1.currentValue } }
    private var totalPnL: Double { totalValue - totalInvestment }
    private var totalPnLPct: Double {
        totalInvestment > 0 ? (totalPnL / totalInvestment) * 100 : 0
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("날짜 선택", selection: $scanDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section {
                    if assets.isEmpty {
                        Text("종목을 추가해주세요")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(assets) { asset in
                            assetRow(asset)
                        }
                        .onDelete { offsets in assets.remove(atOffsets: offsets) }
                    }

                    Button {
                        showAddAsset = true
                    } label: {
                        Label("종목 추가", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("종목 (\(assets.count)개)")
                }

                if !assets.isEmpty {
                    Section("요약") {
                        summaryRow("총 매입금액", totalInvestment.formattedKRW(), .primary)
                        summaryRow("총 평가금액", totalValue.formattedKRW(), .primary)
                        summaryRow(
                            "누적 손익",
                            totalPnL.signedPrefix + totalPnL.formattedKRW()
                                + " (\(totalPnLPct.signedPrefix)\(String(format: "%.2f%%", totalPnLPct)))",
                            totalPnL >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9),
                            bold: true
                        )
                    }
                }
            }
            .navigationTitle("직접 입력")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        vm.addRecord(ScanRecord(date: scanDate, assets: assets))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(assets.isEmpty)
                }
            }
            .sheet(isPresented: $showAddAsset) {
                AddAssetView { asset in assets.append(asset) }
            }
        }
    }

    private func assetRow(_ asset: AssetEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(asset.name)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 6) {
                Text("\(asset.quantity.formattedQuantity())주")
                Text("·")
                Text("매입 \(asset.averagePrice.formattedKRW())")
                Text("·")
                Text("현재 \(asset.currentPrice.formattedKRW())")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func summaryRow(_ label: String, _ value: String, _ color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(color)
        }
    }
}
