import 'dart:math';

/// 외부 패키지 없이 충분히 고유한 ID 생성 (timestamp + 랜덤)
class IdGen {
  static final _rand = Random();

  static String next() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    // 웹(dart2js)에서는 비트 시프트가 32비트로 처리되어 1<<32 가 무너진다.
    // 모든 플랫폼에서 안전한 양수 상한(2^31-1)을 사용한다.
    final r = _rand.nextInt(0x7fffffff).toRadixString(36);
    final r2 = _rand.nextInt(0x7fffffff).toRadixString(36);
    return '$ts-$r$r2';
  }
}
