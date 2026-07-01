import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/asset.dart';
import '../models/history.dart';
import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../widgets/value_line_chart.dart';
import 'asset_edit_screen.dart';

class AssetDetailScreen extends ConsumerWidget {
  final String assetId;
  const AssetDetailScreen({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetProvider).valueOrNull ?? [];
    Asset? found;
    for (final a in assets) {
      if (a.id == assetId) {
        found = a;
        break;
      }
    }
    final historyAsync = ref.watch(assetHistoryProvider(assetId));

    if (found == null) {
      return const Scaffold(body: Center(child: Text('자산을 찾을 수 없습니다.')));
    }
    // 클로저 캡처 시 null 승격이 되지 않으므로 비-널 변수로 고정
    final Asset asset = found;

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AssetEditScreen(asset: asset),
            )),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (histories) =>
            _Body(asset: asset, histories: histories),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Asset asset;
  final List<History> histories;
  const _Body({required this.asset, required this.histories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('yyyy-MM-dd HH:mm', 'ko_KR');
    // 평가금액 추이: afterValue가 평가금액을 반영하는 이벤트만 사용
    final points = histories
        .where((h) => h.afterValue > 0)
        .map((h) => MapEntry(h.date, h.afterValue))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${asset.category.label}${asset.ticker != null ? ' · ${asset.ticker}' : ''}'),
                const SizedBox(height: 8),
                Text(Fmt.won(asset.currentValue),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('목표 비중 ${Fmt.percent(asset.targetWeight)}'),
                if (asset.quantity != null)
                  Text('수량 ${Fmt.number(asset.quantity!)}'),
                if (asset.price != null)
                  Text('현재가 ${Fmt.won(asset.price!)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('평가금액 추이', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ValueLineChart(points: points),
          ),
        ),
        const SizedBox(height: 16),
        Text('변동 이력', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (histories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('이력이 없습니다.'),
          ),
        ...histories.map((h) => Card(
              child: ListTile(
                dense: true,
                leading: _typeBadge(h),
                title: Text('${h.type.label}  ${Fmt.wonSigned(h.amount)}'),
                subtitle: Text(
                    '${df.format(h.date)}\n${Fmt.won(h.beforeValue)} → ${Fmt.won(h.afterValue)}${h.memo != null ? '\n${h.memo}' : ''}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () =>
                      ref.read(historyProvider.notifier).delete(h.id),
                ),
              ),
            )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _typeBadge(History h) {
    final isBuy = h.amount > 0;
    return CircleAvatar(
      radius: 16,
      backgroundColor: (isBuy ? Colors.blue : Colors.red).withOpacity(0.15),
      child: Icon(
        isBuy ? Icons.arrow_upward : Icons.arrow_downward,
        size: 16,
        color: isBuy ? Colors.blue : Colors.red,
      ),
    );
  }
}
