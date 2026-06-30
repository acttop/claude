import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../services/parser_service.dart';
import 'asset_detail_screen.dart';
import 'asset_edit_screen.dart';
import 'paste_import_screen.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  Future<void> _pasteImport(BuildContext context, WidgetRef ref) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text ?? '';
    if (text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클립보드가 비어 있습니다. 분석 결과를 먼저 복사하세요.')),
        );
      }
      return;
    }
    final result = ParserService.parse(text);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PasteImportScreen(initialText: text, initialResult: result),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetProvider);
    final total = ref.watch(totalValueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('자산 관리'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.content_paste),
            label: const Text('붙여넣기'),
            onPressed: () => _pasteImport(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AssetEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (assets) {
          if (assets.isEmpty) {
            return _EmptyAssets(onPaste: () => _pasteImport(context, ref));
          }
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('전체 ${Fmt.won(total)} · ${assets.length}개',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ...assets.map((a) => _AssetTile(asset: a, total: total)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _AssetTile extends ConsumerWidget {
  final Asset asset;
  final double total;
  const _AssetTile({required this.asset, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cw = total > 0 ? asset.currentValue / total * 100 : 0.0;
    return Dismissible(
      key: ValueKey(asset.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('자산 삭제'),
                content: Text('"${asset.name}"을(를) 삭제할까요? 관련 이력도 함께 삭제됩니다.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('삭제')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => ref.read(assetProvider.notifier).deleteAsset(asset),
      child: ListTile(
        title: Text(asset.name),
        subtitle: Text(
            '${asset.category.label}${asset.ticker != null ? ' · ${asset.ticker}' : ''}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Fmt.won(asset.currentValue),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('현재 ${Fmt.percent(cw)} / 목표 ${Fmt.percent(asset.targetWeight)}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: asset.id)),
        ),
      ),
    );
  }
}

class _EmptyAssets extends StatelessWidget {
  final VoidCallback onPaste;
  const _EmptyAssets({required this.onPaste});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64),
            const SizedBox(height: 16),
            Text('등록된 자산이 없습니다',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'AI 챗봇(Claude 등)에서 분석한 결과를 복사한 뒤\n아래 버튼으로 붙여넣으면 자동 등록됩니다.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.content_paste),
              label: const Text('분석 결과 붙여넣기'),
              onPressed: onPaste,
            ),
          ],
        ),
      ),
    );
  }
}
