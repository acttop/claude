import '../models/asset.dart';
import '../models/enums.dart';
import '../models/rebalance_result.dart';

/// 리밸런싱 계산 옵션
class RebalanceOptions {
  /// 추가 투자금액 (0 이상)
  final double additionalInvestment;

  /// 자산별 목표비중 오버라이드 (assetId -> 비중%). null이면 자산의 targetWeight 사용
  final Map<String, double>? targetWeightOverrides;

  /// 최소 거래단위(원). 예: 1000. null이면 반올림 안 함
  final int? roundingUnit;

  /// 수수료/세금율 (예: 0.0015 = 0.15%). 거래금액 × 비율
  final double feeRate;

  const RebalanceOptions({
    this.additionalInvestment = 0,
    this.targetWeightOverrides,
    this.roundingUnit,
    this.feeRate = 0,
  });
}

/// 순수 계산 로직 (UI/저장소 비의존). 단위 테스트 대상.
class RebalanceService {
  /// 목표비중 합계 (%)
  static double targetWeightSum(
    List<Asset> assets, {
    Map<String, double>? overrides,
  }) {
    return assets.fold<double>(
      0.0,
      (s, a) => s + (overrides?[a.id] ?? a.targetWeight),
    );
  }

  /// 비중 합이 100%에 충분히 가까운지(±0.1%p)
  static bool isWeightBalanced(
    List<Asset> assets, {
    Map<String, double>? overrides,
  }) {
    return (targetWeightSum(assets, overrides: overrides) - 100).abs() <= 0.1;
  }

  /// 위험자산(국내/해외 주식, ETF) 목표비중 합. 연금계좌 상한 검증용.
  static double riskAssetTargetWeight(
    List<Asset> assets, {
    Map<String, double>? overrides,
  }) {
    const risky = {
      AssetCategory.domesticStock,
      AssetCategory.foreignStock,
      AssetCategory.etf,
    };
    return assets
        .where((a) => risky.contains(a.category))
        .fold<double>(0.0, (s, a) => s + (overrides?[a.id] ?? a.targetWeight));
  }

  static double _round(double v, int? unit) {
    if (unit == null || unit <= 0) return v;
    return (v / unit).round() * unit.toDouble();
  }

  static double _weightOf(Asset a, Map<String, double>? overrides) =>
      overrides?[a.id] ?? a.targetWeight;

  /// 진입점: 모드에 따라 분기
  static RebalanceResult calculate(
    List<Asset> assets,
    RebalanceMode mode,
    RebalanceOptions options,
  ) {
    switch (mode) {
      case RebalanceMode.full:
        return _calculateFull(assets, options);
      case RebalanceMode.buyOnly:
        return _calculateBuyOnly(assets, options);
    }
  }

  static List<String> _commonWarnings(
    List<Asset> assets,
    RebalanceOptions o,
  ) {
    final warnings = <String>[];
    final sum = targetWeightSum(assets, overrides: o.targetWeightOverrides);
    if ((sum - 100).abs() > 0.1) {
      warnings.add('목표 비중 합계가 ${sum.toStringAsFixed(1)}% 입니다. (100%가 아님)');
    }
    return warnings;
  }

  /// 전체 재배분: 매수·매도 모두 허용해 목표 비중에 정확히 맞춤
  static RebalanceResult _calculateFull(
    List<Asset> assets,
    RebalanceOptions o,
  ) {
    final currentTotal = assets.fold<double>(0.0, (s, a) => s + a.currentValue);
    final newTotal = currentTotal + o.additionalInvestment;
    final warnings = _commonWarnings(assets, o);

    // 1차: 목표금액 - 현재금액 = 조정금액 (반올림 적용)
    final deltas = <String, double>{};
    for (final a in assets) {
      final w = _weightOf(a, o.targetWeightOverrides);
      final target = newTotal * (w / 100.0);
      deltas[a.id] = _round(target - a.currentValue, o.roundingUnit);
    }

    // 반올림으로 인한 잔차를 추가 투자금에 맞추기 위해 최대 |조정금액| 항목에 보정
    if (o.roundingUnit != null && assets.isNotEmpty) {
      final sumDelta = deltas.values.fold<double>(0.0, (s, v) => s + v);
      final residual = o.additionalInvestment - sumDelta;
      if (residual.abs() >= 1) {
        final target = assets.reduce(
          (x, y) => deltas[x.id]!.abs() >= deltas[y.id]!.abs() ? x : y,
        );
        deltas[target.id] = deltas[target.id]! + residual;
      }
    }

    final lines = _buildLines(assets, deltas, newTotal, o);
    return RebalanceResult(
      mode: RebalanceMode.full,
      currentTotal: currentTotal,
      additionalInvestment: o.additionalInvestment,
      newTotal: newTotal,
      lines: lines,
      warnings: warnings,
    );
  }

  /// 추가금 매수만(No-Sell): 부족분에만 추가 투자금을 배분, 매도 없음
  static RebalanceResult _calculateBuyOnly(
    List<Asset> assets,
    RebalanceOptions o,
  ) {
    final currentTotal = assets.fold<double>(0.0, (s, a) => s + a.currentValue);
    final newTotal = currentTotal + o.additionalInvestment;
    final warnings = _commonWarnings(assets, o);
    if (o.additionalInvestment <= 0) {
      warnings.add('추가금 매수만 모드에서는 추가 투자금이 0보다 커야 거래가 발생합니다.');
    }

    // 각 자산의 부족분 (목표금액 - 현재금액 > 0)
    final shortfall = <String, double>{};
    double totalShortfall = 0;
    for (final a in assets) {
      final w = _weightOf(a, o.targetWeightOverrides);
      final target = newTotal * (w / 100.0);
      final s = target - a.currentValue;
      final v = s > 0 ? s : 0.0;
      shortfall[a.id] = v;
      totalShortfall += v;
    }

    final buy = <String, double>{for (final a in assets) a.id: 0.0};
    double cash = o.additionalInvestment;

    if (cash > 0 && totalShortfall > 0) {
      if (cash >= totalShortfall) {
        // 모든 부족분을 채우고, 남은 현금은 목표비중대로 전체 자산에 추가 배분
        for (final a in assets) {
          buy[a.id] = shortfall[a.id]!;
        }
        cash -= totalShortfall;
        if (cash > 0) {
          final wSum =
              targetWeightSum(assets, overrides: o.targetWeightOverrides);
          if (wSum > 0) {
            for (final a in assets) {
              final w = _weightOf(a, o.targetWeightOverrides);
              buy[a.id] = buy[a.id]! + cash * (w / wSum);
            }
          }
        }
      } else {
        // 추가금이 부족분 합보다 작음 → 부족분 비율대로 배분
        for (final a in assets) {
          buy[a.id] = cash * (shortfall[a.id]! / totalShortfall);
        }
      }
    }

    // 반올림 적용 + 잔차 보정(추가 투자금 총액 유지)
    if (o.roundingUnit != null) {
      double rounded = 0;
      for (final a in assets) {
        buy[a.id] = _round(buy[a.id]!, o.roundingUnit);
        rounded += buy[a.id]!;
      }
      final residual = o.additionalInvestment - rounded;
      if (residual.abs() >= 1) {
        // 가장 많이 매수하는 항목에 잔차 반영(음수가 되지 않도록 보호)
        final candidates = assets.where((a) => buy[a.id]! > 0).toList();
        if (candidates.isNotEmpty) {
          final target = candidates
              .reduce((x, y) => buy[x.id]! >= buy[y.id]! ? x : y);
          final adjusted = buy[target.id]! + residual;
          buy[target.id] = adjusted < 0 ? 0 : adjusted;
        }
      }
    }

    final lines = _buildLines(assets, buy, newTotal, o);
    return RebalanceResult(
      mode: RebalanceMode.buyOnly,
      currentTotal: currentTotal,
      additionalInvestment: o.additionalInvestment,
      newTotal: newTotal,
      lines: lines,
      warnings: warnings,
    );
  }

  static List<RebalanceLine> _buildLines(
    List<Asset> assets,
    Map<String, double> deltas,
    double newTotal,
    RebalanceOptions o,
  ) {
    final currentTotal = assets.fold<double>(0.0, (s, a) => s + a.currentValue);
    // 거래 후 실제 총액(반올림/잔차로 newTotal과 미세하게 다를 수 있음)
    final afterTotal = assets.fold<double>(
      0.0,
      (s, a) => s + a.currentValue + (deltas[a.id] ?? 0),
    );
    return assets.map((a) {
      final delta = deltas[a.id] ?? 0;
      final afterValue = a.currentValue + delta;
      final currentWeight =
          currentTotal > 0 ? a.currentValue / currentTotal * 100 : 0.0;
      final afterWeight =
          afterTotal > 0 ? afterValue / afterTotal * 100 : 0.0;
      final fee = delta.abs() * o.feeRate;
      return RebalanceLine(
        assetId: a.id,
        name: a.name,
        currentValue: a.currentValue,
        currentWeight: currentWeight,
        targetWeight: _weightOf(a, o.targetWeightOverrides),
        delta: delta,
        afterValue: afterValue,
        afterWeight: afterWeight,
        fee: fee,
      );
    }).toList();
  }
}
