import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';
import '../models/history.dart';
import '../models/snapshot.dart';
import 'repository.dart';

/// 웹(Flutter Web)용 저장소. wasm 없이 localStorage(SharedPreferences)에
/// JSON으로 영속화한다. iOS Safari 포함 모든 브라우저에서 동작.
class WebStorageService implements PortfolioRepository {
  WebStorageService._();
  static final WebStorageService instance = WebStorageService._();

  static const _kAssets = 'ar_assets';
  static const _kHistories = 'ar_histories';
  static const _kSnapshots = 'ar_snapshots';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<Map<String, dynamic>>> _load(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _save(String key, List<Map<String, dynamic>> rows) async {
    final p = await _p;
    await p.setString(key, jsonEncode(rows));
  }

  // ---------- Asset ----------
  @override
  Future<List<Asset>> getAssets() async {
    final rows = await _load(_kAssets);
    final assets = rows.map(Asset.fromJson).toList();
    assets.sort((a, b) => a.name.compareTo(b.name));
    return assets;
  }

  @override
  Future<void> upsertAsset(Asset a) async {
    final rows = await _load(_kAssets);
    rows.removeWhere((m) => m['id'] == a.id);
    rows.add(a.toJson());
    await _save(_kAssets, rows);
  }

  @override
  Future<void> deleteAsset(String id) async {
    final assets = await _load(_kAssets);
    assets.removeWhere((m) => m['id'] == id);
    await _save(_kAssets, assets);
    final hist = await _load(_kHistories);
    hist.removeWhere((m) => m['assetId'] == id);
    await _save(_kHistories, hist);
  }

  // ---------- History ----------
  @override
  Future<List<History>> getHistories({String? assetId}) async {
    final rows = await _load(_kHistories);
    var hist = rows.map(History.fromJson).toList();
    if (assetId != null) {
      hist = hist.where((h) => h.assetId == assetId).toList();
    }
    hist.sort((a, b) => b.date.compareTo(a.date));
    return hist;
  }

  @override
  Future<void> insertHistory(History h) async {
    final rows = await _load(_kHistories);
    rows.removeWhere((m) => m['id'] == h.id);
    rows.add(h.toJson());
    await _save(_kHistories, rows);
  }

  @override
  Future<void> deleteHistory(String id) async {
    final rows = await _load(_kHistories);
    rows.removeWhere((m) => m['id'] == id);
    await _save(_kHistories, rows);
  }

  // ---------- Snapshot ----------
  @override
  Future<List<Snapshot>> getSnapshots() async {
    final rows = await _load(_kSnapshots);
    final snaps = rows.map(Snapshot.fromJson).toList();
    snaps.sort((a, b) => b.date.compareTo(a.date));
    return snaps;
  }

  @override
  Future<void> insertSnapshot(Snapshot s) async {
    final rows = await _load(_kSnapshots);
    rows.removeWhere((m) => m['id'] == s.id);
    rows.add(s.toJson());
    await _save(_kSnapshots, rows);
  }

  @override
  Future<void> deleteSnapshot(String id) async {
    final rows = await _load(_kSnapshots);
    rows.removeWhere((m) => m['id'] == id);
    await _save(_kSnapshots, rows);
  }

  // ---------- 백업 ----------
  @override
  Future<String> exportJson() async {
    final assets = await _load(_kAssets);
    final histories = await _load(_kHistories);
    final snapshots = await _load(_kSnapshots);
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'assets': assets,
      'histories': histories,
      'snapshots': snapshots,
    });
  }

  @override
  Future<void> importJson(String jsonStr, {bool replace = true}) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    List<Map<String, dynamic>> pick(String k) =>
        ((data[k] as List?) ?? []).cast<Map<String, dynamic>>();
    if (replace) {
      await _save(_kAssets, pick('assets'));
      await _save(_kHistories, pick('histories'));
      await _save(_kSnapshots, pick('snapshots'));
    } else {
      final a = await _load(_kAssets)..addAll(pick('assets'));
      final h = await _load(_kHistories)..addAll(pick('histories'));
      final s = await _load(_kSnapshots)..addAll(pick('snapshots'));
      await _save(_kAssets, a);
      await _save(_kHistories, h);
      await _save(_kSnapshots, s);
    }
  }
}
