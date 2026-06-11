import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct AssetWidgetEntry: TimelineEntry {
    let date: Date
    let assetData: AssetWidgetData
    let portfolioData: PortfolioWidgetData?
}

// MARK: - Provider

struct AssetScannerProvider: TimelineProvider {
    func placeholder(in context: Context) -> AssetWidgetEntry {
        AssetWidgetEntry(date: Date(), assetData: .placeholder, portfolioData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (AssetWidgetEntry) -> Void) {
        completion(AssetWidgetEntry(
            date: Date(),
            assetData: WidgetDataStore.loadAssetData() ?? .placeholder,
            portfolioData: WidgetDataStore.loadPortfolioData()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AssetWidgetEntry>) -> Void) {
        let entry = AssetWidgetEntry(
            date: Date(),
            assetData: WidgetDataStore.loadAssetData() ?? .placeholder,
            portfolioData: WidgetDataStore.loadPortfolioData()
        )
        // 앱이 WidgetCenter.reloadAllTimelines()를 호출하므로 1시간 자동 갱신은 보조용
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget Configuration

struct AssetScannerWidget: Widget {
    let kind = "AssetScannerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AssetScannerProvider()) { entry in
            AssetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("자산 현황")
        .description("포트폴리오 현황, 일별·누적 손익을 홈 화면에서 확인합니다")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Root Entry View

struct AssetWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: AssetWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            case .systemLarge:  LargeWidgetView(entry: entry)
            default:            SmallWidgetView(entry: entry)
            }
        }
        .applyWidgetBackground()
    }
}

// MARK: - Small Widget  (2×2)

struct SmallWidgetView: View {
    let entry: AssetWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack(spacing: 3) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("자산 현황")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer(minLength: 6)

            // 총 평가금액
            Text(krw(entry.assetData.totalValue))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer(minLength: 8)

            // 일별 손익
            miniPnLRow(
                label: "일별",
                amount: signed(entry.assetData.dailyPnL) + krwShort(entry.assetData.dailyPnL),
                percent: signedPct(entry.assetData.dailyPnLPercent),
                color: pnlColor(entry.assetData.dailyPnL)
            )

            Spacer(minLength: 5)

            // 누적 손익
            miniPnLRow(
                label: "누적",
                amount: signed(entry.assetData.cumulativePnL) + krwShort(entry.assetData.cumulativePnL),
                percent: signedPct(entry.assetData.cumulativePnLPercent),
                color: pnlColor(entry.assetData.cumulativePnL)
            )

            Spacer(minLength: 6)

            // 업데이트 시각
            Text(entry.assetData.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                .font(.system(size: 8))
                .foregroundStyle(.quaternary)
        }
        .padding(14)
    }

    private func miniPnLRow(label: String, amount: String, percent: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(amount)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(percent)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Medium Widget  (4×2)

struct MediumWidgetView: View {
    let entry: AssetWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더
            HStack {
                Label("자산 현황", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.assetData.updatedAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 총 평가금액
            Text(krw(entry.assetData.totalValue))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            // 두 P&L 카드
            HStack(spacing: 10) {
                pnlCard(
                    title: "일별 손익",
                    amount: signed(entry.assetData.dailyPnL) + krw(entry.assetData.dailyPnL),
                    percent: signedPct(entry.assetData.dailyPnLPercent),
                    color: pnlColor(entry.assetData.dailyPnL)
                )
                pnlCard(
                    title: "누적 손익",
                    amount: signed(entry.assetData.cumulativePnL) + krw(entry.assetData.cumulativePnL),
                    percent: signedPct(entry.assetData.cumulativePnLPercent),
                    color: pnlColor(entry.assetData.cumulativePnL)
                )
            }
        }
        .padding(14)
    }

    private func pnlCard(title: String, amount: String, percent: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(percent)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Large Widget  (4×4)

struct LargeWidgetView: View {
    let entry: AssetWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 헤더
            HStack {
                Label("자산 현황", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.assetData.updatedAt.formatted(
                    .dateTime.month(.twoDigits).day(.twoDigits).hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 총 평가금액
            Text(krw(entry.assetData.totalValue))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            // P&L 두 카드
            HStack(spacing: 10) {
                largePnLCard(
                    title: "일별 손익",
                    amount: signed(entry.assetData.dailyPnL) + krw(entry.assetData.dailyPnL),
                    percent: signedPct(entry.assetData.dailyPnLPercent),
                    color: pnlColor(entry.assetData.dailyPnL)
                )
                largePnLCard(
                    title: "누적 손익",
                    amount: signed(entry.assetData.cumulativePnL) + krw(entry.assetData.cumulativePnL),
                    percent: signedPct(entry.assetData.cumulativePnLPercent),
                    color: pnlColor(entry.assetData.cumulativePnL)
                )
            }

            Divider()

            // 환율 + 리밸런싱 상태
            HStack(spacing: 12) {
                if let p = entry.portfolioData, p.usdKrw > 0 {
                    Label(String(format: "USD  %.0f원", p.usdKrw),
                          systemImage: "dollarsign.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let p = entry.portfolioData, p.needsRebalancing {
                    Label(String(format: "리밸런싱 %.1f%%", p.maxDeviation),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Label("포트폴리오 균형", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                }
            }

            Divider()

            // 보유 종목 상위 3개
            VStack(spacing: 6) {
                ForEach(entry.assetData.topHoldings.prefix(3)) { h in
                    holdingRow(h)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func largePnLCard(title: String, amount: String, percent: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(percent)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func holdingRow(_ h: AssetWidgetData.HoldingItem) -> some View {
        let color: Color = h.pnlPercent >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9)
        return HStack {
            Text(h.name)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .layoutPriority(1)
            Spacer()
            Text(krwShort(h.value))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(signedPct(h.pnlPercent))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 54, alignment: .trailing)
        }
    }
}

// MARK: - Background (iOS 16/17 분기)

extension View {
    @ViewBuilder
    func applyWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            background(Color(.systemBackground))
        }
    }
}

// MARK: - Helpers (widget-local formatting)

private func pnlColor(_ value: Double) -> Color {
    value >= 0 ? .red : Color(red: 0.1, green: 0.3, blue: 0.9)
}

private func signed(_ v: Double) -> String { v >= 0 ? "+" : "" }

private func signedPct(_ v: Double) -> String {
    String(format: v >= 0 ? "+%.2f%%" : "%.2f%%", v)
}

private func krw(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    let n = f.string(from: NSNumber(value: abs(value))) ?? "0"
    return (value < 0 ? "-" : "") + n + "원"
}

// 소형 위젯용 단축 표기: 만·억 단위
private func krwShort(_ value: Double) -> String {
    let abs = Swift.abs(value)
    let sign = value < 0 ? "-" : ""
    if abs >= 100_000_000 { return sign + String(format: "%.1f억", abs / 100_000_000) }
    if abs >= 10_000      { return sign + String(format: "%.0f만", abs / 10_000) }
    return krw(value)
}
