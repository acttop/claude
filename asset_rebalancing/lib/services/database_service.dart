import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/asset.dart';
import '../models/history.dart';
import '../models/snapshot.dart';
import 'repository.dart';

/// SQLite 기반 영구 저장소 (네이티브). offline-first, 로컬 전용.
class DatabaseService implements PortfolioRepository {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'asset_rebalancing.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    // 웹에서는 파일시스템 경로 대신 DB 이름만 사용(IndexedDB에 저장)
    final String path;
    if (kIsWeb) {
      path = _dbName;
    } else {
      final dir = await getDatabasesPath();
      path = p.join(dir, _dbName);
    }
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE assets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ticker TEXT,
        category TEXT NOT NULL,
        currentValue REAL NOT NULL,
        quantity REAL,
        price REAL,
        targetWeight REAL NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE histories (
        id TEXT PRIMARY KEY,
        assetId TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        beforeValue REAL NOT NULL,
        afterValue REAL NOT NULL,
        amount REAL NOT NULL,
        memo TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE snapshots (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        totalValue REAL NOT NULL,
        breakdown TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_history_asset ON histories(assetId)');
    await db.execute('CREATE INDEX idx_history_date ON histories(date)');
  }

  // ---------- Asset ----------
  Future<List<Asset>> getAssets() async {
    final db = await database;
    final rows = await db.query('assets', orderBy: 'name ASC');
    return rows.map(Asset.fromMap).toList();
  }

  Future<void> upsertAsset(Asset a) async {
    final db = await database;
    await db.insert('assets', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAsset(String id) async {
    final db = await database;
    await db.delete('assets', where: 'id = ?', whereArgs: [id]);
    await db.delete('histories', where: 'assetId = ?', whereArgs: [id]);
  }

  // ---------- History ----------
  Future<List<History>> getHistories({String? assetId}) async {
    final db = await database;
    final rows = await db.query(
      'histories',
      where: assetId != null ? 'assetId = ?' : null,
      whereArgs: assetId != null ? [assetId] : null,
      orderBy: 'date DESC',
    );
    return rows.map(History.fromMap).toList();
  }

  Future<void> insertHistory(History h) async {
    final db = await database;
    await db.insert('histories', h.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteHistory(String id) async {
    final db = await database;
    await db.delete('histories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Snapshot ----------
  Future<List<Snapshot>> getSnapshots() async {
    final db = await database;
    final rows = await db.query('snapshots', orderBy: 'date DESC');
    return rows.map(Snapshot.fromMap).toList();
  }

  Future<void> insertSnapshot(Snapshot s) async {
    final db = await database;
    await db.insert('snapshots', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSnapshot(String id) async {
    final db = await database;
    await db.delete('snapshots', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- 백업: 내보내기 / 가져오기 ----------
  Future<String> exportJson() async {
    final assets = await getAssets();
    final histories = await getHistories();
    final snapshots = await getSnapshots();
    final data = {
      'version': _dbVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'assets': assets.map((a) => a.toJson()).toList(),
      'histories': histories.map((h) => h.toJson()).toList(),
      'snapshots': snapshots.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// JSON 백업을 가져온다. replace=true면 기존 데이터를 모두 지우고 대체.
  Future<void> importJson(String jsonStr, {bool replace = true}) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final db = await database;
    await db.transaction((txn) async {
      if (replace) {
        await txn.delete('assets');
        await txn.delete('histories');
        await txn.delete('snapshots');
      }
      for (final a in (data['assets'] as List? ?? [])) {
        await txn.insert('assets', Asset.fromJson(a).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final h in (data['histories'] as List? ?? [])) {
        await txn.insert('histories', History.fromJson(h).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final s in (data['snapshots'] as List? ?? [])) {
        await txn.insert('snapshots', Snapshot.fromJson(s).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
