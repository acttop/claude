import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../services/parser_service.dart';

/// 붙여넣기 → 실시간 파싱 미리보기 → 적용
class PasteImportScreen extends ConsumerStatefulWidget {
  final String initialText;
  const PasteImportScreen({super.key, this.initialText = ''});

  @override
  ConsumerState<PasteImportScreen> createState() => _PasteImportScreenState();
}

class _PasteImportScreenState extends ConsumerState<PasteImportScreen> {
  late TextEditingController _textCtrl;
  ParseResult _result = const ParseResult(
      assets: [], errors: [], detectedFormat: 'unknown');

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.initialText);
    _parse();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() {
      _result = _textCtrl.text.trim().isEmpty
          ? const ParseResult(assets: [], errors: [], detectedFormat: 'unknown')
          : ParserService.parse(_textCtrl.text);
    });
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final t = clip?.text ?? '';
      if (t.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('클립보드가 비어 있거나 접근이 제한되었습니다. 아래 칸에 직접 붙여넣어 주세요.')));
        }
        return;
      }
      _textCtrl.text = t;
      _parse();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('클립보드를 읽을 수 없습니다. 아래 칸에 직접 붙여넣어 주세요.')));
      }
    }
  }

  bool _applying = false;

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final summary =
          await ref.read(assetProvider.notifier).applyParsed(_result.assets);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('신규 ${summary.created}건 · 갱신 ${summary.updated}건 적용되었습니다')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('적용 중 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight =
        _result.assets.fold<double>(0, (s, a) => s + a.targetWeight);
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 결과 붙여넣기'),
        actions: [
          TextButton(
            onPressed: _result.hasData ? _apply : null,
            child: Text('적용${_result.hasData ? ' (${_result.assets.length})' : ''}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '아래 칸에 마크다운 표 / CSV / JSON 을 붙여넣으면 자동으로 인식됩니다.\n'
            '(입력칸을 길게 눌러 “붙여넣기”를 선택하세요.)',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste),
                label: const Text('클립보드에서 가져오기'),
                onPressed: _pasteFromClipboard,
              ),
              const Spacer(),
              if (_textCtrl.text.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('지우기'),
                  onPressed: () {
                    _textCtrl.clear();
                    _parse();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _textCtrl,
            maxLines: 8,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  '| 상품명 | 카테고리 | 평가금액 | 목표비중 |\n| ... | ... | ... | ... |',
            ),
            onChanged: (_) => _parse(),
          ),
          const SizedBox(height: 12),
          if (_result.detectedFormat != 'unknown')
            Text('인식된 형식: ${_formatLabel(_result.detectedFormat)}',
                style: Theme.of(context).textTheme.labelMedium),
          if (_result.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('파싱 경고/오류',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 4),
                  ..._result.errors.map((e) =>
                      Text('• $e', style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('인식된 자산 ${_result.assets.length}개',
                  style: Theme.of(context).textTheme.titleMedium),
              if (_result.hasData)
                Text('목표비중 합 ${Fmt.percent(totalWeight)}',
                    style: TextStyle(
                      color: (totalWeight - 100).abs() <= 0.1
                          ? Colors.green
                          : Colors.orange,
                    )),
            ],
          ),
          const Divider(),
          ..._result.assets.map((a) => Card(
                child: ListTile(
                  dense: true,
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
              )),
          if (_result.hasData) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_applying
                  ? '적용 중...'
                  : '${_result.assets.length}개 자산 적용'),
              onPressed: _applying ? null : _apply,
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            '※ 동일한 상품명이 이미 있으면 평가금액·비중을 갱신(평가금액갱신 이력), '
            '없으면 신규 등록합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
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
