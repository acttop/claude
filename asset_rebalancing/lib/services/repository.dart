import '../models/asset.dart';
import '../models/history.dart';
import '../models/snapshot.dart';

/// 자산/이력/스냅샷 영속화 저장소 인터페이스.
/// 네이티브는 SQLite(sqflite), 웹은 localStorage 구현을 사용한다.
abstract class PortfolioRepository {
  Future<List<Asset>> getAssets();
  Future<void> upsertAsset(Asset a);
  Future<void> deleteAsset(String id);

  Future<List<History>> getHistories({String? assetId});
  Future<void> insertHistory(History h);
  Future<void> deleteHistory(String id);

  Future<List<Snapshot>> getSnapshots();
  Future<void> insertSnapshot(Snapshot s);
  Future<void> deleteSnapshot(String id);

  Future<String> exportJson();
  Future<void> importJson(String jsonStr, {bool replace = true});
}
