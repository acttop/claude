import 'dart:math';

/// 외부 패키지 없이 충분히 고유한 ID 생성 (timestamp + 랜덤)
class IdGen {
  static final _rand = Random();

  static String next() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(1 << 32).toRadixString(36);
    return '$ts-$r';
  }
}
