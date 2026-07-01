import 'package:flutter_test/flutter_test.dart';
import 'package:asset_rebalancing/models/asset.dart';
import 'package:asset_rebalancing/models/enums.dart';
import 'package:asset_rebalancing/services/rebalance_service.dart';

Asset mk(String id, String name, AssetCategory cat, double value, double weight) {
  return Asset(
    id: id,
    name: name,
    category: cat,
    currentValue: value,
    targetWeight: weight,
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  // 샘플 포트폴리오: 총 10,000,000원
  List<Asset> sample() => [
        mk('1', 'TIGER 미국S&P500', AssetCategory.foreignStock, 5000000, 40),
        mk('2', 'KODEX 200', AssetCategory.domesticStock, 3000000, 25),
        mk('3', '현금', AssetCategory.cash, 2000000, 35),
      ];

  group('전체 재배분 모드', () {
    test('추가 투자금 0원이면 매수합=매도합 (순현금흐름 0)', () {
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.full,
        const RebalanceOptions(additionalInvestment: 0),
      );

      // 총액 10,000,000 유지
      expect(result.currentTotal, 10000000);
      expect(result.newTotal, 10000000);

      // 목표금액: S&P 4,000,000 / KODEX 2,500,000 / 현금 3,500,000
      final line1 = result.lines.firstWhere((l) => l.assetId == '1');
      final line2 = result.lines.firstWhere((l) => l.assetId == '2');
      final line3 = result.lines.firstWhere((l) => l.assetId == '3');

      expect(line1.delta, closeTo(-1000000, 0.01)); // 매도 100만
      expect(line2.delta, closeTo(-500000, 0.01)); // 매도 50만
      expect(line3.delta, closeTo(1500000, 0.01)); // 매수 150만

      // 매수합 == 매도합
      expect(result.totalBuy, closeTo(result.totalSell, 0.01));
      expect(result.netCashFlow, closeTo(0, 0.01));
    });

    test('추가 투자금 5,000,000원 → 조정금액 합 ≈ 추가 투자금', () {
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.full,
        const RebalanceOptions(additionalInvestment: 5000000),
      );
      expect(result.newTotal, 15000000);

      // 조정금액 합 == 추가 투자금
      final sumDelta = result.lines.fold<double>(0, (s, l) => s + l.delta);
      expect(sumDelta, closeTo(5000000, 0.01));

      // 거래 후 비중이 목표 비중과 일치
      for (final l in result.lines) {
        expect(l.afterWeight, closeTo(l.targetWeight, 0.01));
      }
    });

    test('거래 후 평가금액 = 목표금액', () {
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.full,
        const RebalanceOptions(additionalInvestment: 5000000),
      );
      final line1 = result.lines.firstWhere((l) => l.assetId == '1');
      // 15,000,000 * 40% = 6,000,000
      expect(line1.afterValue, closeTo(6000000, 0.01));
    });

    test('최소 거래단위(1,000원) 반올림 적용 시에도 조정금액 합 == 추가금', () {
      final assets = [
        mk('1', 'A', AssetCategory.etf, 3333333, 33.33),
        mk('2', 'B', AssetCategory.etf, 3333333, 33.33),
        mk('3', 'C', AssetCategory.etf, 3333334, 33.34),
      ];
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.full,
        const RebalanceOptions(
            additionalInvestment: 1000000, roundingUnit: 1000),
      );
      final sumDelta = result.lines.fold<double>(0, (s, l) => s + l.delta);
      expect(sumDelta, closeTo(1000000, 0.5));
      // 각 거래금액이 1,000원 단위
      for (final l in result.lines) {
        expect(l.delta % 1000, closeTo(0, 0.001));
      }
    });

    test('수수료율 0.15% 적용 시 거래금액 비례 수수료 계산', () {
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.full,
        const RebalanceOptions(additionalInvestment: 0, feeRate: 0.0015),
      );
      final line3 = result.lines.firstWhere((l) => l.assetId == '3');
      expect(line3.fee, closeTo(1500000 * 0.0015, 0.01)); // 2,250원
    });
  });

  group('추가금 매수만 모드 (No-Sell)', () {
    test('매도가 전혀 발생하지 않는다', () {
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.buyOnly,
        const RebalanceOptions(additionalInvestment: 3000000),
      );
      expect(result.totalSell, 0);
      for (final l in result.lines) {
        expect(l.delta >= 0, true);
      }
    });

    test('매수 금액 합 ≈ 추가 투자금', () {
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.buyOnly,
        const RebalanceOptions(additionalInvestment: 3000000),
      );
      expect(result.totalBuy, closeTo(3000000, 0.01));
    });

    test('부족분(현금) 자산에 우선 배분된다', () {
      // 신규총액 13,000,000. 목표: S&P 5.2M(부족 0.2M), KODEX 3.25M(부족 0.25M),
      // 현금 4.55M(부족 2.55M). 총 부족분 3.0M == 추가금 → 정확히 부족분만큼 매수
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.buyOnly,
        const RebalanceOptions(additionalInvestment: 3000000),
      );
      final line3 = result.lines.firstWhere((l) => l.assetId == '3');
      // 현금이 가장 부족하므로 가장 많이 매수
      expect(line3.delta, closeTo(2550000, 1));
    });

    test('추가금이 부족분 합보다 작으면 부족분 비율대로 분배', () {
      // 추가금 1,000,000. 부족분 비율대로 배분, 매도 없음
      final assets = sample();
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.buyOnly,
        const RebalanceOptions(additionalInvestment: 1000000),
      );
      expect(result.totalBuy, closeTo(1000000, 1));
      expect(result.totalSell, 0);
    });
  });

  group('검증 헬퍼', () {
    test('목표비중 합계 100% 판정', () {
      final assets = sample();
      expect(RebalanceService.isWeightBalanced(assets), true);
    });

    test('비중 합 != 100%면 경고 포함', () {
      final assets = [
        mk('1', 'A', AssetCategory.etf, 5000000, 50),
        mk('2', 'B', AssetCategory.etf, 5000000, 40), // 합 90
      ];
      final result = RebalanceService.calculate(
        assets,
        RebalanceMode.full,
        const RebalanceOptions(),
      );
      expect(result.warnings.isNotEmpty, true);
    });

    test('위험자산 비중 합 계산 (연금 상한 검증용)', () {
      final assets = sample();
      // S&P(40) + KODEX(25) = 65, 현금 제외
      expect(RebalanceService.riskAssetTargetWeight(assets), closeTo(65, 0.01));
    });
  });
}
