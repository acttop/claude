import 'package:intl/intl.dart';

/// 숫자/통화 포맷 유틸
class Fmt {
  static final NumberFormat _won = NumberFormat('#,##0', 'ko_KR');
  static final NumberFormat _wonSigned = NumberFormat('+#,##0;-#,##0', 'ko_KR');

  /// 1234567 -> "₩1,234,567"
  static String won(num v) => '₩${_won.format(v.round())}';

  /// 부호 포함. 1234 -> "+1,234", -1234 -> "-1,234"
  static String wonSigned(num v) {
    if (v == 0) return '0';
    return _wonSigned.format(v.round());
  }

  /// 천 단위 콤마만 (기호 없음)
  static String number(num v) => _won.format(v.round());

  /// 비중 % 소수점 1자리. 42.5 -> "42.5%"
  static String percent(num v) => '${v.toStringAsFixed(1)}%';

  /// 문자열에서 숫자만 추출 (₩, 원, 콤마, %, 공백 제거). 실패 시 null
  static double? parseNumber(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s
        .replaceAll('₩', '')
        .replaceAll('원', '')
        .replaceAll('%', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll(' ', ''); // non-breaking space
    if (s.isEmpty || s == '-') return null;
    return double.tryParse(s);
  }
}
