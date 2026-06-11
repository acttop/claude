import SwiftUI

struct AddAssetView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (AssetEntry) -> Void

    @State private var name = ""
    @State private var symbol = ""
    @State private var quantityStr = ""
    @State private var avgPriceStr = ""
    @State private var curPriceStr = ""
    @FocusState private var focused: Field?

    enum Field { case name, symbol, quantity, avgPrice, curPrice }

    private func parseDouble(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ""))
    }

    private var quantity: Double { parseDouble(quantityStr) ?? 0 }
    private var avgPrice: Double { parseDouble(avgPriceStr) ?? 0 }
    private var curPrice: Double { parseDouble(curPriceStr) ?? 0 }

    private var isValid: Bool {
        !name.isEmpty && quantity > 0 && avgPrice > 0 && curPrice > 0
    }

    private var previewPnL: Double { (curPrice - avgPrice) * quantity }
    private var previewPnLPct: Double { avgPrice > 0 ? ((curPrice - avgPrice) / avgPrice) * 100 : 0 }

    var body: some View {
        NavigationView {
            Form {
                Section("종목 정보") {
                    TextField("종목명 (예: 삼성전자)", text: $name)
                        .focused($focused, equals: .name)
                    TextField("종목코드 (선택, 예: 005930)", text: $symbol)
                        .focused($focused, equals: .symbol)
                }

                Section("수량 및 가격") {
                    numberField("보유수량", binding: $quantityStr, placeholder: "0", unit: "주", field: .quantity)
                    numberField("매입단가", binding: $avgPriceStr, placeholder: "0", unit: "원", field: .avgPrice)
                    numberField("현재가", binding: $curPriceStr, placeholder: "0", unit: "원", field: .curPrice)
                }

                if isValid {
                    Section("미리보기") {
                        HStack {
                            Text("매입금액")
                            Spacer()
                            Text((avgPrice * quantity).formattedKRW())
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("평가금액")
                            Spacer()
                            Text((curPrice * quantity).formattedKRW())
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("평가손익")
                            Spacer()
                            Text(previewPnL.signedPrefix + previewPnL.formattedKRW()
                                 + " (\(previewPnLPct.signedPrefix)\(String(format: "%.2f%%", previewPnLPct)))")
                                .fontWeight(.semibold)
                                .foregroundStyle(previewPnL >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9))
                        }
                    }
                }
            }
            .navigationTitle("종목 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("추가") {
                        onAdd(AssetEntry(name: name, symbol: symbol, quantity: quantity,
                                        averagePrice: avgPrice, currentPrice: curPrice))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear { focused = .name }
        }
    }

    private func numberField(_ label: String, binding: Binding<String>,
                              placeholder: String, unit: String, field: Field) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focused, equals: field)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}
