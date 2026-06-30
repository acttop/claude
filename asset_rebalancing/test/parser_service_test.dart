import 'package:flutter_test/flutter_test.dart';
import 'package:asset_rebalancing/models/enums.dart';
import 'package:asset_rebalancing/services/parser_service.dart';

void main() {
  group('마크다운 표 파싱 (A)', () {
    test('표준 마크다운 표를 파싱한다', () {
      const input = '''
| 상품명 | 카테고리 | 평가금액 | 목표비중 |
|--------|----------|----------|----------|
| TIGER 미국S&P500 | 해외주식 | 5,000,000 | 40 |
| KODEX 200 | 국내주식 | 3,000,000 | 25 |
| 현금 | 현금 | 2,000,000 | 35 |
''';
      final r = ParserService.parse(input);
      expect(r.detectedFormat, 'markdown');
      expect(r.assets.length, 3);
      expect(r.assets[0].name, 'TIGER 미국S&P500');
      expect(r.assets[0].category, AssetCategory.foreignStock);
      expect(r.assets[0].currentValue, 5000000);
      expect(r.assets[0].targetWeight, 40);
      expect(r.assets[2].category, AssetCategory.cash);
    });

    test('통화기호/원 표기를 제거한다', () {
      const input = '''
| 상품명 | 카테고리 | 평가금액 | 목표비중 |
|---|---|---|---|
| 채권ETF | 채권 | ₩1,500,000원 | 20% |
''';
      final r = ParserService.parse(input);
      expect(r.assets.single.currentValue, 1500000);
      expect(r.assets.single.targetWeight, 20);
    });
  });

  group('CSV 파싱 (B)', () {
    test('헤더 있는 CSV를 파싱한다', () {
      const input = '''
상품명,카테고리,평가금액,목표비중
TIGER 미국S&P500,해외주식,5000000,40
KODEX 200,국내주식,3000000,25
''';
      final r = ParserService.parse(input);
      expect(r.detectedFormat, 'csv');
      expect(r.assets.length, 2);
      expect(r.assets[1].name, 'KODEX 200');
      expect(r.assets[1].currentValue, 3000000);
    });
  });

  group('JSON 파싱 (C)', () {
    test('JSON 배열을 파싱한다', () {
      const input =
          '[{"name":"TIGER 미국S&P500","category":"해외주식","currentValue":5000000,"targetWeight":40}]';
      final r = ParserService.parse(input);
      expect(r.detectedFormat, 'json');
      expect(r.assets.single.name, 'TIGER 미국S&P500');
      expect(r.assets.single.currentValue, 5000000);
      expect(r.assets.single.targetWeight, 40);
    });

    test('단일 JSON 객체도 허용한다', () {
      const input =
          '{"name":"현금","category":"현금","currentValue":2000000,"targetWeight":35}';
      final r = ParserService.parse(input);
      expect(r.assets.single.category, AssetCategory.cash);
    });
  });

  group('오류 처리', () {
    test('빈 입력은 에러를 반환한다', () {
      final r = ParserService.parse('   ');
      expect(r.hasData, false);
      expect(r.errors.isNotEmpty, true);
    });

    test('숫자를 읽지 못한 줄을 안내한다', () {
      const input = '''
상품명,카테고리,평가금액,목표비중
이상한행,주식,abc,xyz
정상행,현금,1000000,100
''';
      final r = ParserService.parse(input);
      // 정상행 1건은 파싱, 이상한행은 에러 안내
      expect(r.assets.length, 1);
      expect(r.errors.any((e) => e.contains('이상한행') || e.contains('2번째')), true);
    });
  });
}
