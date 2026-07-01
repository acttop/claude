/// 플랫폼별 DB 초기화 진입점.
/// 웹에서는 db_init_web.dart, 그 외에는 db_init_stub.dart가 선택된다.
export 'db_init_stub.dart' if (dart.library.html) 'db_init_web.dart';
