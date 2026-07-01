import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// 웹에서 sqflite가 동작하도록 IndexedDB 기반 팩토리를 설정한다.
/// (web/sqlite3.wasm, web/sqflite_sw.js 필요 — CI에서 setup 단계로 생성)
void initPlatformDatabase() {
  databaseFactory = databaseFactoryFfiWeb;
}
