import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/asset.dart';
import '../models/enums.dart';
import '../models/history.dart';
import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../widgets/value_line_chart.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _assetFilter; // assetId
  HistoryType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(historyProvider);
    final assets = ref.watch(assetProvider).valueOrNull ?? [];
    final snapsAsync = ref.watch(snapshotProvider);
    final assetById = {for (final a in assets) a.id: a};

    return Scaffold(
      appBar: AppBar(
        title: const Text('이력 / 리포트'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            onSelected: (v) => _export(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'json', child: Text('전체 JSON 복사')),
              PopupMenuItem(value: 'csv', child: Text('이력 CSV 복사')),
            ],
          ),
        ],
      ),
      body: histAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (allHist) {
          final filtered = allHist.where((h) {
            if (_assetFilter != null && h.assetId != _assetFilter) return false;
            if (_typeFilter != null && h.type != _typeFilter) return false;
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _snapshotSection(snapsAsync),
              const SizedBox(height: 8),
              _filters(assets),
              const Divider(),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('이력이 없습니다.')),
                ),
              ...filtered.map((h) => _historyTile(h, assetById)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _snapshotSection(AsyncValue snapsAsync) {
    return snapsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (snaps) {
        if (snaps.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('스냅샷이 없습니다. 홈 화면에서 스냅샷을 저장하면 전체 자산 추이를 볼 수 있습니다.'),
            ),
          );
        }
        final points = (snaps as List)
            .map((s) => MapEntry(s.date as DateTime, s.totalValue as double))
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('전체 자산 추이 (스냅샷 ${snaps.length}개)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ValueLineChart(points: points),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filters(List<Asset> assets) {
    return Wrap(
      spacing: 8,
      children: [
        DropdownButton<String?>(
          value: _assetFilter,
          hint: const Text('자산 전체'),
          items: [
            const DropdownMenuItem(value: null, child: Text('자산 전체')),
            ...assets.map((a) =>
                DropdownMenuItem(value: a.id, child: Text(a.name))),
          ],
          onChanged: (v) => setState(() => _assetFilter = v),
        ),
        DropdownButton<HistoryType?>(
          value: _typeFilter,
          hint: const Text('유형 전체'),
          items: [
            const DropdownMenuItem(value: null, child: Text('유형 전체')),
            ...HistoryType.values.map((t) =>
                DropdownMenuItem(value: t, child: Text(t.label))),
          ],
          onChanged: (v) => setState(() => _typeFilter = v),
        ),
      ],
    );
  }

  Widget _historyTile(History h, Map<String, Asset> assetById) {
    final df = DateFormat('yyyy-MM-dd HH:mm', 'ko_KR');
    final name = assetById[h.assetId]?.name ?? '(삭제된 자산)';
    return ListTile(
      dense: true,
      title: Text('$name · ${h.type.label}'),
      subtitle: Text(
          '${df.format(h.date)} · ${Fmt.won(h.beforeValue)} → ${Fmt.won(h.afterValue)}'),
      trailing: Text(
        h.amount == 0 ? '-' : Fmt.wonSigned(h.amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: h.amount > 0
              ? Colors.blue
              : h.amount < 0
                  ? Colors.red
                  : Colors.grey,
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, String type) async {
    String content;
    if (type == 'json') {
      content = await ref.read(dbProvider).exportJson();
    } else {
      final hist = ref.read(historyProvider).valueOrNull ?? [];
      final assets = ref.read(assetProvider).valueOrNull ?? [];
      final byId = {for (final a in assets) a.id: a.name};
      final df = DateFormat('yyyy-MM-dd HH:mm');
      final sb = StringBuffer('자산,일시,유형,변동전,변동후,금액,메모\n');
      for (final h in hist) {
        sb.writeln(
            '"${byId[h.assetId] ?? ''}",${df.format(h.date)},${h.type.label},${h.beforeValue},${h.afterValue},${h.amount},"${h.memo ?? ''}"');
      }
      content = sb.toString();
    }
    await Clipboard.setData(ClipboardData(text: content));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.toUpperCase()}를 클립보드에 복사했습니다.')),
      );
    }
  }
}
