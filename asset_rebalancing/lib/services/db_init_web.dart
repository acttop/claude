import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// 웹에서 sqflite가 동작하도록 IndexedDB 기반 팩토리를 설정한다.
/// iOS Safari는 SharedWorker를 지원하지 않으므로, 워커를 쓰지 않는
/// NoWebWorker 변형을 사용해 메인 스레드에서 sqlite3.wasm을 구동한다.
/// (web/sqlite3.wasm 필요 — CI에서 setup 단계로 생성)
void initPlatformDatabase() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
