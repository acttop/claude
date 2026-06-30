import 'dart:convert';

import '../models/enums.dart';
import 'format_utils.dart';

/// 붙여넣기 파싱으로 추출된 한 행 (자산 후보)
class ParsedAsset {
  final String name;
  final AssetCategory category;
  final double currentValue;
  final double targetWeight;
  final String? ticker;
  final double? quantity;
  final double? price;

  const ParsedAsset({
    required this.name,
    required this.category,
    required this.currentValue,
    required this.targetWeight,
    this.ticker,
    this.quantity,
    this.price,
  });

  ParsedAsset copyWith({
    String? name,
    AssetCategory? category,
    double? currentValue,
    double? targetWeight,
  }) =>
      ParsedAsset(
        name: name ?? this.name,
        category: category ?? this.category,
        currentValue: currentValue ?? this.currentValue,
        targetWeight: targetWeight ?? this.targetWeight,
        ticker: ticker,
        quantity: quantity,
        price: price,
      );
}

class ParseResult {
  final List<ParsedAsset> assets;
  final List<String> errors; // 실패한 줄 안내
  final String detectedFormat;

  const ParseResult({
    required this.assets,
    required this.errors,
    required this.detectedFormat,
  });

  bool get hasData => assets.isNotEmpty;
}

/// 챗봇 분석 결과(마크다운 표 / CSV / JSON) 파서
class ParserService {
  /// 헤더에서 컬럼 인덱스를 매핑하기 위한 별칭
  static const _nameKeys = ['상품명', '종목', '종목명', '자산', '자산명', 'name', '이름'];
  static const _categoryKeys = ['카테고리', '분류', '종류', 'category', '자산군'];
  static const _valueKeys = [
    '평가금액',
    '평가액',
    '금액',
    '현재금액',
    '평가금액(원)',
    'currentvalue',
    'value',
    '평가'
  ];
  static const _weightKeys = [
    '목표비중',
    '목표 비중',
    '비중',
    'targetweight',
    'weight',
    '목표'
  ];
  static const _tickerKeys = ['종목코드', '코드', 'ticker', 'symbol'];

  static ParseResult parse(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return const ParseResult(
        assets: [],
        errors: ['입력이 비어 있습니다.'],
        detectedFormat: 'unknown',
      );
    }
    // 1) JSON
    if (text.startsWith('[') || text.startsWith('{')) {
      return _parseJson(text);
    }
    // 2) 마크다운 표 ( | 포함하는 줄이 다수 )
    final lines = const LineSplitter().convert(text);
    final pipeLines = lines.where((l) => l.contains('|')).length;
    if (pipeLines >= 2) {
      return _parseMarkdown(lines);
    }
    // 3) CSV
    if (lines.any((l) => l.contains(','))) {
      return _parseCsv(lines);
    }
    return ParseResult(
      assets: const [],
      errors: ['형식을 인식하지 못했습니다. 마크다운 표 / CSV / JSON 중 하나여야 합니다.'],
      detectedFormat: 'unknown',
    );
  }

  // ---------- JSON ----------
  static ParseResult _parseJson(String text) {
    final errors = <String>[];
    final assets = <ParsedAsset>[];
    try {
      final decoded = jsonDecode(text);
      final List list =
          decoded is List ? decoded : [decoded]; // 단일 객체도 허용
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is! Map) {
          errors.add('JSON ${i + 1}번째 항목이 객체가 아닙니다.');
          continue;
        }
        final m = item.map((k, v) => MapEntry(k.toString().toLowerCase(), v));
        final name = (m['name'] ?? m['상품명'] ?? m['종목명'])?.toString().trim();
        if (name == null || name.isEmpty) {
          errors.add('JSON ${i + 1}번째 항목에 상품명(name)이 없습니다.');
          continue;
        }
        final value = Fmt.parseNumber(
            (m['currentvalue'] ?? m['value'] ?? m['평가금액'])?.toString());
        final weight = Fmt.parseNumber(
            (m['targetweight'] ?? m['weight'] ?? m['목표비중'])?.toString());
        assets.add(ParsedAsset(
          name: name,
          category: AssetCategory.fromString(
              (m['category'] ?? m['카테고리'])?.toString()),
          currentValue: value ?? 0,
          targetWeight: weight ?? 0,
          ticker: (m['ticker'] ?? m['종목코드'])?.toString(),
          quantity: Fmt.parseNumber((m['quantity'] ?? m['수량'])?.toString()),
          price: Fmt.parseNumber((m['price'] ?? m['현재가'])?.toString()),
        ));
      }
    } catch (e) {
      errors.add('JSON 파싱 실패: $e');
    }
    return ParseResult(
        assets: assets, errors: errors, detectedFormat: 'json');
  }

  // ---------- Markdown ----------
  static ParseResult _parseMarkdown(List<String> lines) {
    final rows = <List<String>>[];
    for (final line in lines) {
      final t = line.trim();
      if (!t.contains('|')) continue;
      // 구분선 (|---|---|) 무시
      if (RegExp(r'^\|?[\s:\-\|]+\|?$').hasMatch(t)) continue;
      var cells = t.split('|').map((c) => c.trim()).toList();
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isEmpty) continue;
      rows.add(cells);
    }
    return _parseTabular(rows, 'markdown');
  }

  // ---------- CSV ----------
  static ParseResult _parseCsv(List<String> lines) {
    final rows = <List<String>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      rows.add(_splitCsvLine(line));
    }
    return _parseTabular(rows, 'csv');
  }

  /// 따옴표 안의 콤마를 보존하는 간단한 CSV 분리
  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  // ---------- 공통 표 처리 ----------
  static ParseResult _parseTabular(List<List<String>> rows, String format) {
    final errors = <String>[];
    final assets = <ParsedAsset>[];
    if (rows.isEmpty) {
      return ParseResult(
          assets: assets,
          errors: ['데이터 행이 없습니다.'],
          detectedFormat: format);
    }

    // 헤더 추정: 첫 행에 헤더 키워드가 있으면 헤더로 사용
    final header = rows.first.map((c) => c.toLowerCase().trim()).toList();
    final hasHeader = header.any((h) =>
        _matchIndex(_nameKeys, [h]) == 0 ||
        _matchAny(h, _nameKeys) ||
        _matchAny(h, _valueKeys) ||
        _matchAny(h, _weightKeys));

    int nameIdx = 0, catIdx = 1, valIdx = 2, weightIdx = 3, tickerIdx = -1;
    int startRow = 0;

    if (hasHeader) {
      nameIdx = _matchIndex(_nameKeys, header);
      catIdx = _matchIndex(_categoryKeys, header);
      valIdx = _matchIndex(_valueKeys, header);
      weightIdx = _matchIndex(_weightKeys, header);
      tickerIdx = _matchIndex(_tickerKeys, header);
      startRow = 1;
      if (nameIdx < 0) nameIdx = 0;
      if (valIdx < 0) valIdx = 2;
      if (weightIdx < 0) weightIdx = 3;
    }

    for (var r = startRow; r < rows.length; r++) {
      final cells = rows[r];
      final lineNo = r + 1;
      String at(int idx) =>
          (idx >= 0 && idx < cells.length) ? cells[idx] : '';

      final name = at(nameIdx).trim();
      if (name.isEmpty) {
        errors.add('$lineNo번째 줄: 상품명이 비어 있어 건너뜀 → "${cells.join(' | ')}"');
        continue;
      }
      final value = Fmt.parseNumber(at(valIdx));
      final weight = Fmt.parseNumber(at(weightIdx));
      if (value == null && weight == null) {
        errors.add('$lineNo번째 줄: 평가금액/목표비중을 숫자로 읽지 못했습니다 → "${cells.join(' | ')}"');
        continue;
      }
      assets.add(ParsedAsset(
        name: name,
        category: AssetCategory.fromString(catIdx >= 0 ? at(catIdx) : null),
        currentValue: value ?? 0,
        targetWeight: weight ?? 0,
        ticker: tickerIdx >= 0 && at(tickerIdx).isNotEmpty
            ? at(tickerIdx)
            : null,
      ));
    }

    if (assets.isEmpty && errors.isEmpty) {
      errors.add('유효한 데이터 행을 찾지 못했습니다.');
    }
    return ParseResult(
        assets: assets, errors: errors, detectedFormat: format);
  }

  static bool _matchAny(String header, List<String> keys) =>
      keys.any((k) => header == k.toLowerCase() || header.contains(k.toLowerCase()));

  /// keys 중 하나라도 매칭되는 헤더의 인덱스. 없으면 -1
  static int _matchIndex(List<String> keys, List<String> header) {
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase().trim();
      if (keys.any((k) => h == k.toLowerCase() || h.contains(k.toLowerCase()))) {
        return i;
      }
    }
    return -1;
  }
}
