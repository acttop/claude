import SwiftUI

struct AddPortfolioAssetView: View {
    @Environment(\.dismiss) private var dismiss
    var editingAsset: PortfolioAsset? = nil
    let onSave: (PortfolioAsset) -> Void

    @State private var name = ""
    @State private var symbol = ""
    @State private var category = ""
    @State private var currency: AssetCurrency = .krw
    @State private var targetWeightStr = ""
    @State private var currentPriceStr = ""
    @State private var quantityStr = ""
    @FocusState private var focused: Field?

    enum Field { case name, symbol, weight, price, qty }

    private func num(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ""))
    }

    private var targetWeight: Double { num(targetWeightStr) ?? 0 }
    private var currentPrice: Double { num(currentPriceStr) ?? 0 }
    private var quantity: Double { num(quantityStr) ?? 0 }
    private var isValid: Bool { !name.isEmpty && targetWeight > 0 && targetWeight <= 100 && currentPrice > 0 }

    private let categories = ["해외주식", "국내주식", "채권", "금", "현금", "부동산", "기타"]

    var body: some View {
        NavigationView {
            Form {
                Section("종목 정보") {
                    TextField("종목명 (예: TIGER 미국S&P500)", text: $name)
                        .focused($focused, equals: .name)
                    TextField("종목코드/심볼 (선택)", text: $symbol)
                        .focused($focused, equals: .symbol)
                    Picker("통화", selection: $currency) {
                        ForEach(AssetCurrency.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    Picker("자산군", selection: $category) {
                        Text("선택 안함").tag("")
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    HStack {
                        Text("목표 비중")
                        Spacer()
                        TextField("0", text: $targetWeightStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .weight)
                            .frame(width: 70)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("목표 비중")
                } footer: {
                    Text("포트폴리오 내 이 종목의 목표 보유 비율입니다")
                        .font(.caption)
                }

                Section("현재 보유 현황") {
                    HStack {
                        Text(currency == .usd ? "현재가 (USD)" : "현재가 (원)")
                        Spacer()
                        TextField("0", text: $currentPriceStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .price)
                            .frame(width: 110)
                        Text(currency.symbol)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("보유수량")
                        Spacer()
                        TextField("0", text: $quantityStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .qty)
                            .frame(width: 80)
                        Text("주")
                            .foregroundStyle(.secondary)
                    }
                }

                if isValid && quantity > 0 {
                    Section("미리보기") {
                        HStack {
                            Text("현재 평가금액")
                            Spacer()
                            Text(currency.symbol + (currentPrice * quantity).formattedQuantity())
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("목표 비중")
                            Spacer()
                            Text(String(format: "%.0f%%", targetWeight))
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle(editingAsset == nil ? "종목 추가" : "종목 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        var asset = PortfolioAsset(
                            name: name, symbol: symbol, currency: currency,
                            targetWeight: targetWeight, currentPrice: currentPrice,
                            quantity: quantity, category: category
                        )
                        if let e = editingAsset { asset.id = e.id }
                        onSave(asset)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                guard let a = editingAsset else { focused = .name; return }
                name = a.name
                symbol = a.symbol
                category = a.category
                currency = a.currency
                targetWeightStr = String(format: "%.0f", a.targetWeight)
                currentPriceStr = String(format: currency == .usd ? "%.2f" : "%.0f", a.currentPrice)
                quantityStr = a.quantity.formattedQuantity()
            }
        }
    }
}
