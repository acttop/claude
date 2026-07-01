import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';
import '../models/history.dart';
import '../models/snapshot.dart';
import 'repository.dart';

/// 웹(Flutter Web)용 저장소.
///
/// 메모리를 1차 저장소로 사용하고, localStorage(SharedPreferences)에는
/// best-effort로만 영속화한다. iOS Safari 프라이빗 모드처럼 localStorage
/// 쓰기가 실패/지연되는 환경에서도 앱이 멈추거나 예외로 죽지 않는다.
class WebStorageService implements PortfolioRepository {
  WebStorageService._();
  static final WebStorageService instance = WebStorageService._();

  static const _kAssets = 'ar_assets';
  static const _kHistories = 'ar_histories';
  static const _kSnapshots = 'ar_snapshots';

  final Map<String, List<Map<String, dynamic>>> _mem = {
    _kAssets: [],
    _kHistories: [],
    _kSnapshots: [],
  };
  bool _loaded = false;
  SharedPreferences? _prefs;

  Future<SharedPreferences?> _prefsOrNull() async {
    if (_prefs != null) return _prefs;
    try {
      _prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      _prefs = null;
    }
    return _prefs;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final p = await _prefsOrNull();
    if (p == null) return; // localStorage 사용 불가 → 메모리로만 동작
    for (final key in [_kAssets, _kHistories, _kSnapshots]) {
      try {
        final raw = p.getString(key);
        if (raw != null && raw.isNotEmpty) {
          _mem[key] = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        }
      } catch (_) {/* 무시 */}
    }
  }

  List<Map<String, dynamic>> _rows(String key) => _mem[key]!;

  Future<void> _persist(String key) async {
    final p = await _prefsOrNull();
    if (p == null) return;
    try {
      await p.setString(key, jsonEncode(_mem[key]));
    } catch (_) {/* 프라이빗 모드 등: 메모리에는 이미 반영됨 */}
  }

  // ---------- Asset ----------
  @override
  Future<List<Asset>> getAssets() async {
    await _ensureLoaded();
    final assets = _rows(_kAssets).map(Asset.fromJson).toList();
    assets.sort((a, b) => a.name.compareTo(b.name));
    return assets;
  }

  @override
  Future<void> upsertAsset(Asset a) async {
    await _ensureLoaded();
    final rows = _rows(_kAssets)..removeWhere((m) => m['id'] == a.id);
    rows.add(a.toJson());
    unawaited(_persist(_kAssets));
  }

  @override
  Future<void> deleteAsset(String id) async {
    await _ensureLoaded();
    _rows(_kAssets).removeWhere((m) => m['id'] == id);
    _rows(_kHistories).removeWhere((m) => m['assetId'] == id);
    unawaited(_persist(_kAssets));
    unawaited(_persist(_kHistories));
  }

  // ---------- History ----------
  @override
  Future<List<History>> getHistories({String? assetId}) async {
    await _ensureLoaded();
    var hist = _rows(_kHistories).map(History.fromJson).toList();
    if (assetId != null) {
      hist = hist.where((h) => h.assetId == assetId).toList();
    }
    hist.sort((a, b) => b.date.compareTo(a.date));
    return hist;
  }

  @override
  Future<void> insertHistory(History h) async {
    await _ensureLoaded();
    final rows = _rows(_kHistories)..removeWhere((m) => m['id'] == h.id);
    rows.add(h.toJson());
    unawaited(_persist(_kHistories));
  }

  @override
  Future<void> deleteHistory(String id) async {
    await _ensureLoaded();
    _rows(_kHistories).removeWhere((m) => m['id'] == id);
    unawaited(_persist(_kHistories));
  }

  // ---------- Snapshot ----------
  @override
  Future<List<Snapshot>> getSnapshots() async {
    await _ensureLoaded();
    final snaps = _rows(_kSnapshots).map(Snapshot.fromJson).toList();
    snaps.sort((a, b) => b.date.compareTo(a.date));
    return snaps;
  }

  @override
  Future<void> insertSnapshot(Snapshot s) async {
    await _ensureLoaded();
    final rows = _rows(_kSnapshots)..removeWhere((m) => m['id'] == s.id);
    rows.add(s.toJson());
    unawaited(_persist(_kSnapshots));
  }

  @override
  Future<void> deleteSnapshot(String id) async {
    await _ensureLoaded();
    _rows(_kSnapshots).removeWhere((m) => m['id'] == id);
    unawaited(_persist(_kSnapshots));
  }

  // ---------- 백업 ----------
  @override
  Future<String> exportJson() async {
    await _ensureLoaded();
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'assets': _rows(_kAssets),
      'histories': _rows(_kHistories),
      'snapshots': _rows(_kSnapshots),
    });
  }

  @override
  Future<void> importJson(String jsonStr, {bool replace = true}) async {
    await _ensureLoaded();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    List<Map<String, dynamic>> pick(String k) =>
        ((data[k] as List?) ?? []).cast<Map<String, dynamic>>();
    if (replace) {
      _mem[_kAssets] = pick('assets');
      _mem[_kHistories] = pick('histories');
      _mem[_kSnapshots] = pick('snapshots');
    } else {
      _rows(_kAssets).addAll(pick('assets'));
      _rows(_kHistories).addAll(pick('histories'));
      _rows(_kSnapshots).addAll(pick('snapshots'));
    }
    unawaited(_persist(_kAssets));
    unawaited(_persist(_kHistories));
    unawaited(_persist(_kSnapshots));
  }
}
