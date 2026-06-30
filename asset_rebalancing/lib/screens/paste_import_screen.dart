import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../services/parser_service.dart';

/// 붙여넣기 → 파싱 미리보기 → 적용
class PasteImportScreen extends ConsumerStatefulWidget {
  final String initialText;
  final ParseResult initialResult;
  const PasteImportScreen({
    super.key,
    required this.initialText,
    required this.initialResult,
  });

  @override
  ConsumerState<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends ConsumerState<PasteImportScreen> {
  late TextEditingController _textCtrl;
  late ParseResult _result;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialText);
    _result = widget.initialResult;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _reparse() {
    setState(() => _result = ParserService.parse(_textCtrl.text));
  }

  Future<void> _apply() async {
    final summary =
        await ref.read(assetProvider.notifier).applyParsed(_result.assets);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신규 ${summary.created}건 · 갱신 ${summary.updated}건 적용')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight =
        _result.assets.fold<double>(0, (s, a) => s + a.targetWeight);
    return Scaffold(
      appBar: AppBar(
        title: const Text('붙여넣기 미리보기'),
        actions: [
          TextButton(
            onPressed: _result.hasData ? _apply : null,
            child: const Text('적용'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('인식된 형식: ${_formatLabel(_result.detectedFormat)}',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('원본 텍스트 (수정 가능)'),
            tilePadding: EdgeInsets.zero,
            children: [
              TextField(
                controller: _textCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '마크다운 표 / CSV / JSON',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('다시 파싱'),
                onPressed: _reparse,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_result.errors.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('파싱 경고/오류',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  ..._result.errors.map((e) => Text('• $e',
                      style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('인식된 자산 ${_result.assets.length}개',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('목표비중 합 ${Fmt.percent(totalWeight)}',
                  style: TextStyle(
                    color: (totalWeight - 100).abs() <= 0.1
                        ? Colors.green
                        : Colors.orange,
                  )),
            ],
          ),
          const Divider(),
          ..._result.assets.asMap().entries.map((entry) {
            final a = entry.value;
            return Card(
              child: ListTile(
                title: Text(a.name),
                subtitle: Text(a.category.label),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.won(a.currentValue)),
                    Text('목표 ${Fmt.percent(a.targetWeight)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            '※ 동일한 상품명이 이미 있으면 평가금액·비중을 갱신하고 “평가금액갱신” 이력을 남깁니다. '
            '없으면 신규 등록합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  String _formatLabel(String f) {
    switch (f) {
      case 'markdown':
        return '마크다운 표';
      case 'csv':
        return 'CSV';
      case 'json':
        return 'JSON';
      default:
        return '인식 실패';
    }
  }
}
