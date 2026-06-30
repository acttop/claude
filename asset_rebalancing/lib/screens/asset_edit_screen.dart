import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../models/enums.dart';
import '../providers/portfolio_provider.dart';
import '../services/format_utils.dart';
import '../services/id_gen.dart';

/// 자산 추가/수정
class AssetEditScreen extends ConsumerStatefulWidget {
  final Asset? asset; // null이면 신규
  const AssetEditScreen({super.key, this.asset});

  @override
  ConsumerState<AssetEditScreen> createState() => _AssetEditScreenState();
}

class _AssetEditScreenState extends ConsumerState<AssetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _ticker;
  late TextEditingController _value;
  late TextEditingController _weight;
  late TextEditingController _quantity;
  late TextEditingController _price;
  AssetCategory _category = AssetCategory.etf;

  bool get _isEdit => widget.asset != null;

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _name = TextEditingController(text: a?.name ?? '');
    _ticker = TextEditingController(text: a?.ticker ?? '');
    _value =
        TextEditingController(text: a != null ? Fmt.number(a.currentValue) : '');
    _weight =
        TextEditingController(text: a != null ? a.targetWeight.toString() : '');
    _quantity =
        TextEditingController(text: a?.quantity?.toString() ?? '');
    _price = TextEditingController(text: a?.price?.toString() ?? '');
    _category = a?.category ?? AssetCategory.etf;
  }

  @override
  void dispose() {
    _name.dispose();
    _ticker.dispose();
    _value.dispose();
    _weight.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(assetProvider.notifier);
    final value = Fmt.parseNumber(_value.text) ?? 0;
    final weight = Fmt.parseNumber(_weight.text) ?? 0;

    if (_isEdit) {
      final prev = widget.asset!;
      final updated = prev.copyWith(
        name: _name.text.trim(),
        ticker: _ticker.text.trim().isEmpty ? null : _ticker.text.trim(),
        category: _category,
        currentValue: value,
        targetWeight: weight,
        quantity: Fmt.parseNumber(_quantity.text),
        price: Fmt.parseNumber(_price.text),
      );
      await notifier.updateAsset(updated, previous: prev, memo: '수동 수정');
    } else {
      final asset = Asset(
        id: IdGen.next(),
        name: _name.text.trim(),
        ticker: _ticker.text.trim().isEmpty ? null : _ticker.text.trim(),
        category: _category,
        currentValue: value,
        targetWeight: weight,
        quantity: Fmt.parseNumber(_quantity.text),
        price: Fmt.parseNumber(_price.text),
        updatedAt: DateTime.now(),
      );
      await notifier.addAsset(asset);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '자산 수정' : '자산 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: '상품명 *', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '상품명을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AssetCategory>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: '카테고리', border: OutlineInputBorder()),
              items: AssetCategory.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ticker,
              decoration: const InputDecoration(
                  labelText: '종목코드 (선택)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '현재 평가금액 (원) *',
                  prefixText: '₩ ',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  Fmt.parseNumber(v) == null ? '숫자를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: '목표 비중 (%) *',
                  suffixText: '%',
                  border: OutlineInputBorder()),
              validator: (v) =>
                  Fmt.parseNumber(v) == null ? '숫자를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '수량 (선택)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: '현재가 (선택)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? '저장' : '추가'),
            ),
          ],
        ),
      ),
    );
  }
}
