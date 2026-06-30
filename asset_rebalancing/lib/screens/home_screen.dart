import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../widgets/donut_chart.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetProvider);
    final total = ref.watch(totalValueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('포트폴리오'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (assets) {
          if (assets.isEmpty) return const _EmptyHome();
          return _Dashboard(assets: assets, total: total);
        },
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final List<Asset> assets;
  final double total;
  const _Dashboard({required this.assets, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 괴리도(현재비중 - 목표비중) 절댓값 큰 순서
    final sorted = [...assets];
    double curW(Asset a) => total > 0 ? a.currentValue / total * 100 : 0;
    sorted.sort((a, b) =>
        (curW(b) - b.targetWeight).abs().compareTo((curW(a) - a.targetWeight).abs()));

    final donut = assets
        .map((a) => DonutDatum(a.name, a.currentValue))
        .toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(assetProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('전체 평가금액',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(Fmt.won(total),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${assets.length}개 자산',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 자산 구성',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  DonutChart(data: donut, centerLabel: Fmt.won(total), size: 180),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text('리밸런싱 필요 (괴리 큰 순)',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ...sorted.map((a) {
            final cw = curW(a);
            final dev = cw - a.targetWeight;
            final needsRebalance = dev.abs() >= 3;
            return Card(
              color: needsRebalance
                  ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.4)
                  : null,
              child: ListTile(
                title: Text(a.name),
                subtitle: Text(
                    '현재 ${Fmt.percent(cw)} · 목표 ${Fmt.percent(a.targetWeight)}'),
                trailing: Text(
                  '${dev >= 0 ? '+' : ''}${dev.toStringAsFixed(1)}%p',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: needsRebalance
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('현재 포트폴리오 스냅샷 저장'),
            onPressed: () async {
              await ref.read(snapshotProvider.notifier).saveCurrent(assets);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('스냅샷을 저장했습니다.')),
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.donut_large,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('아직 자산이 없습니다',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '“자산 관리” 탭에서 챗봇 분석 결과를 붙여넣거나\n자산을 직접 추가해 시작하세요.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
