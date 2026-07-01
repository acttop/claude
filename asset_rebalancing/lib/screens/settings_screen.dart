import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/portfolio_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionTitle('화면'),
          ListTile(
            title: const Text('테마'),
            trailing: DropdownButton<ThemeMode>(
              value: s.themeMode,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('시스템')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('라이트')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('다크')),
              ],
              onChanged: (m) => notifier.setThemeMode(m!),
            ),
          ),
          const Divider(),
          const _SectionTitle('리밸런싱 계산'),
          ListTile(
            title: const Text('최소 거래단위'),
            subtitle: const Text('거래금액을 이 단위로 반올림'),
            trailing: DropdownButton<int?>(
              value: s.roundingUnit,
              items: const [
                DropdownMenuItem(value: null, child: Text('없음')),
                DropdownMenuItem(value: 1000, child: Text('1,000원')),
                DropdownMenuItem(value: 10000, child: Text('10,000원')),
                DropdownMenuItem(value: 100000, child: Text('100,000원')),
              ],
              onChanged: (v) => notifier.setRoundingUnit(v),
            ),
          ),
          ListTile(
            title: const Text('수수료·세금율'),
            subtitle: Text('현재 ${(s.feeRate * 100).toStringAsFixed(3)}%'),
            trailing: SizedBox(
              width: 120,
              child: TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(suffixText: '%', isDense: true),
                onSubmitted: (v) {
                  final p = double.tryParse(v);
                  if (p != null) notifier.setFeeRate(p / 100);
                },
              ),
            ),
          ),
          ListTile(
            title: const Text('위험자산 비중 상한'),
            subtitle: Text(s.riskAssetCap == null
                ? '미적용 (예: DC형 연금 70%)'
                : '${s.riskAssetCap!.toStringAsFixed(0)}% 초과 시 경고'),
            trailing: SizedBox(
              width: 120,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                    suffixText: '%', isDense: true, hintText: '없음'),
                onSubmitted: (v) {
                  if (v.trim().isEmpty) {
                    notifier.setRiskCap(null);
                  } else {
                    final p = double.tryParse(v);
                    if (p != null) notifier.setRiskCap(p);
                  }
                },
              ),
            ),
          ),
          const Divider(),
          const _SectionTitle('백업'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('데이터 내보내기 (JSON 복사)'),
            onTap: () async {
              final json = await ref.read(dbProvider).exportJson();
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('백업 JSON을 클립보드에 복사했습니다.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('데이터 가져오기 (JSON 붙여넣기)'),
            subtitle: const Text('기존 데이터를 모두 대체합니다'),
            onTap: () => _importDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _importDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('JSON 가져오기'),
        content: TextField(
          controller: ctrl,
          maxLines: 8,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: '백업 JSON 붙여넣기'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('가져오기')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await ref.read(dbProvider).importJson(ctrl.text);
        ref.invalidate(assetProvider);
        ref.invalidate(historyProvider);
        ref.invalidate(snapshotProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가져오기 완료')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('가져오기 실패: $e')),
          );
        }
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          )),
    );
  }
}
