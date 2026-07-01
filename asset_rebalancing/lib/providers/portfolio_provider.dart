import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../models/enums.dart';
import '../models/history.dart';
import '../models/rebalance_result.dart';
import '../models/snapshot.dart';
import '../services/database_service.dart';
import '../services/id_gen.dart';
import '../services/parser_service.dart';
import '../services/repository.dart';
import '../services/web_storage_service.dart';

/// 플랫폼에 맞는 저장소 선택: 웹은 localStorage, 네이티브는 SQLite
final dbProvider = Provider<PortfolioRepository>(
  (ref) => kIsWeb ? WebStorageService.instance : DatabaseService.instance,
);

/// 자산 목록 상태 (DB 백킹)
class AssetNotifier extends AsyncNotifier<List<Asset>> {
  PortfolioRepository get _db => ref.read(dbProvider);

  @override
  Future<List<Asset>> build() => _db.getAssets();

  Future<void> _reload() async {
    state = AsyncData(await _db.getAssets());
  }

  Future<void> addAsset(Asset asset, {String? memo}) async {
    await _db.upsertAsset(asset);
    await _db.insertHistory(History(
      id: IdGen.next(),
      assetId: asset.id,
      date: DateTime.now(),
      type: HistoryType.create,
      beforeValue: 0,
      afterValue: asset.currentValue,
      amount: asset.currentValue,
      memo: memo ?? '신규 등록',
    ));
    await _reload();
    ref.invalidate(historyProvider);
  }

  /// 평가금액/비중 수정. 이력 자동 기록.
  Future<void> updateAsset(
    Asset updated, {
    required Asset previous,
    String? memo,
  }) async {
    await _db.upsertAsset(updated.copyWith(updatedAt: DateTime.now()));

    if (updated.currentValue != previous.currentValue) {
      await _db.insertHistory(History(
        id: IdGen.next(),
        assetId: updated.id,
        date: DateTime.now(),
        type: HistoryType.valueUpdate,
        beforeValue: previous.currentValue,
        afterValue: updated.currentValue,
        amount: updated.currentValue - previous.currentValue,
        memo: memo,
      ));
    }
    if (updated.targetWeight != previous.targetWeight) {
      await _db.insertHistory(History(
        id: IdGen.next(),
        assetId: updated.id,
        date: DateTime.now(),
        type: HistoryType.weightChange,
        beforeValue: previous.targetWeight,
        afterValue: updated.targetWeight,
        amount: 0,
        memo: memo ?? '목표비중 변경',
      ));
    }
    await _reload();
    ref.invalidate(historyProvider);
  }

  Future<void> deleteAsset(Asset asset) async {
    await _db.deleteAsset(asset.id);
    await _reload();
    ref.invalidate(historyProvider);
  }

  /// 붙여넣기 파싱 결과를 반영: 동일 상품명은 갱신, 없으면 신규등록
  Future<ApplyImportSummary> applyParsed(List<ParsedAsset> parsed) async {
    final existing = await _db.getAssets();
    final byName = {for (final a in existing) a.name.trim(): a};
    int created = 0, updated = 0;

    for (final pa in parsed) {
      final match = byName[pa.name.trim()];
      final now = DateTime.now();
      if (match == null) {
        final asset = Asset(
          id: IdGen.next(),
          name: pa.name,
          ticker: pa.ticker,
          category: pa.category,
          currentValue: pa.currentValue,
          quantity: pa.quantity,
          price: pa.price,
          targetWeight: pa.targetWeight,
          updatedAt: now,
        );
        await _db.upsertAsset(asset);
        await _db.insertHistory(History(
          id: IdGen.next(),
          assetId: asset.id,
          date: now,
          type: HistoryType.create,
          beforeValue: 0,
          afterValue: asset.currentValue,
          amount: asset.currentValue,
          memo: '붙여넣기 신규 등록',
        ));
        created++;
      } else {
        final newAsset = match.copyWith(
          category: pa.category,
          currentValue: pa.currentValue,
          targetWeight: pa.targetWeight,
          ticker: pa.ticker ?? match.ticker,
          updatedAt: now,
        );
        await _db.upsertAsset(newAsset);
        if (newAsset.currentValue != match.currentValue) {
          await _db.insertHistory(History(
            id: IdGen.next(),
            assetId: match.id,
            date: now,
            type: HistoryType.valueUpdate,
            beforeValue: match.currentValue,
            afterValue: newAsset.currentValue,
            amount: newAsset.currentValue - match.currentValue,
            memo: '붙여넣기 평가금액 갱신',
          ));
        }
        updated++;
      }
    }
    await _reload();
    ref.invalidate(historyProvider);
    return ApplyImportSummary(created: created, updated: updated);
  }

  /// 리밸런싱 결과를 이력에 반영: 각 자산 평가금액을 거래 후 금액으로 갱신, 매수/매도 이력 저장
  Future<void> applyRebalance(RebalanceResult result) async {
    final now = DateTime.now();
    final existing = await _db.getAssets();
    final byId = {for (final a in existing) a.id: a};

    for (final line in result.lines) {
      if (line.delta == 0) continue;
      final asset = byId[line.assetId];
      if (asset == null) continue;
      final updated = asset.copyWith(
        currentValue: line.afterValue,
        updatedAt: now,
      );
      await _db.upsertAsset(updated);
      await _db.insertHistory(History(
        id: IdGen.next(),
        assetId: asset.id,
        date: now,
        type: line.delta > 0 ? HistoryType.buy : HistoryType.sell,
        beforeValue: asset.currentValue,
        afterValue: line.afterValue,
        amount: line.delta,
        memo: '리밸런싱 (${result.mode.label})',
      ));
    }
    await _reload();
    ref.invalidate(historyProvider);
  }

  Future<void> refresh() => _reload();
}

class ApplyImportSummary {
  final int created;
  final int updated;
  const ApplyImportSummary({required this.created, required this.updated});
}

final assetProvider =
    AsyncNotifierProvider<AssetNotifier, List<Asset>>(AssetNotifier.new);

/// 전체 평가금액
final totalValueProvider = Provider<double>((ref) {
  final assets = ref.watch(assetProvider).valueOrNull ?? [];
  return assets.fold<double>(0, (s, a) => s + a.currentValue);
});

/// 변동 이력 (assetId 필터 옵션)
class HistoryNotifier extends AsyncNotifier<List<History>> {
  PortfolioRepository get _db => ref.read(dbProvider);

  @override
  Future<List<History>> build() => _db.getHistories();

  Future<void> addManual(History h) async {
    await _db.insertHistory(h);
    state = AsyncData(await _db.getHistories());
  }

  Future<void> delete(String id) async {
    await _db.deleteHistory(id);
    state = AsyncData(await _db.getHistories());
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<History>>(HistoryNotifier.new);

/// 특정 자산의 이력
final assetHistoryProvider =
    FutureProvider.family<List<History>, String>((ref, assetId) async {
  ref.watch(historyProvider); // 무효화 시 함께 갱신
  return ref.read(dbProvider).getHistories(assetId: assetId);
});

/// 스냅샷
class SnapshotNotifier extends AsyncNotifier<List<Snapshot>> {
  PortfolioRepository get _db => ref.read(dbProvider);

  @override
  Future<List<Snapshot>> build() => _db.getSnapshots();

  Future<void> saveCurrent(List<Asset> assets) async {
    final total = assets.fold<double>(0, (s, a) => s + a.currentValue);
    final breakdown = assets
        .map((a) => SnapshotItem(
              name: a.name,
              value: a.currentValue,
              weight: total > 0 ? a.currentValue / total * 100 : 0,
            ))
        .toList();
    await _db.insertSnapshot(Snapshot(
      id: IdGen.next(),
      date: DateTime.now(),
      totalValue: total,
      breakdown: breakdown,
    ));
    state = AsyncData(await _db.getSnapshots());
  }

  Future<void> delete(String id) async {
    await _db.deleteSnapshot(id);
    state = AsyncData(await _db.getSnapshots());
  }
}

final snapshotProvider =
    AsyncNotifierProvider<SnapshotNotifier, List<Snapshot>>(
        SnapshotNotifier.new);
