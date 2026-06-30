import 'enums.dart';

/// 거래 구분
enum TradeAction {
  buy('매수'),
  sell('매도'),
  hold('유지');

  const TradeAction(this.label);
  final String label;
}

/// 자산별 리밸런싱 계산 결과 한 줄
class RebalanceLine {
  final String assetId;
  final String name;
  final double currentValue;
  final double currentWeight; // %
  final double targetWeight; // %
  final double delta; // 조정금액(부호 있음). + 매수 / - 매도
  final double afterValue; // 거래 후 예상 평가금액
  final double afterWeight; // 거래 후 비중 %
  final double fee; // 예상 수수료/세금

  const RebalanceLine({
    required this.assetId,
    required this.name,
    required this.currentValue,
    required this.currentWeight,
    required this.targetWeight,
    required this.delta,
    required this.afterValue,
    required this.afterWeight,
    this.fee = 0,
  });

  TradeAction get action {
    if (delta > 0) return TradeAction.buy;
    if (delta < 0) return TradeAction.sell;
    return TradeAction.hold;
  }

  /// 표시용 거래 금액(절댓값)
  double get tradeAmount => delta.abs();
}

/// 전체 리밸런싱 결과
class RebalanceResult {
  final RebalanceMode mode;
  final double currentTotal;
  final double additionalInvestment;
  final double newTotal;
  final List<RebalanceLine> lines;
  final List<String> warnings;

  const RebalanceResult({
    required this.mode,
    required this.currentTotal,
    required this.additionalInvestment,
    required this.newTotal,
    required this.lines,
    this.warnings = const [],
  });

  double get totalBuy =>
      lines.where((l) => l.delta > 0).fold(0.0, (s, l) => s + l.delta);

  double get totalSell =>
      lines.where((l) => l.delta < 0).fold(0.0, (s, l) => s + l.delta.abs());

  double get totalFee => lines.fold(0.0, (s, l) => s + l.fee);

  /// 순 현금흐름(매수-매도). 추가금 매수만 모드라면 ≈ 추가 투자금
  double get netCashFlow => totalBuy - totalSell;
}
