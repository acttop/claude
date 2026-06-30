import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../models/enums.dart';
import '../models/rebalance_result.dart';
import '../providers/portfolio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/format_utils.dart';
import '../services/rebalance_service.dart';
import '../widgets/donut_chart.dart';

class RebalanceScreen extends ConsumerStatefulWidget {
  const RebalanceScreen({super.key});

  @override
  ConsumerState<RebalanceScreen> createState() => _RebalanceScreenState();
}

class _RebalanceScreenState extends ConsumerState<RebalanceScreen> {
  RebalanceMode _mode = RebalanceMode.full;
  final _investCtrl = TextEditingController(text: '0');
  final Map<String, double> _weights = {}; // assetId -> target weight (override)
  bool _initialized = false;

  @override
  void dispose() {
    _investCtrl.dispose();
    super.dispose();
  }

  void _initWeights(List<Asset> assets) {
    if (_initialized) return;
    for (final a in assets) {
      _weights[a.id] = a.targetWeight;
    }
    _initialized = true;
  }

  double get _additional => Fmt.parseNumber(_investCtrl.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('리밸런싱 계산')),
      body: assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('자산을 먼저 등록하세요.', textAlign: TextAlign.center),
              ),
            );
          }
          _initWeights(assets);

          final overrides = {
            for (final a in assets) a.id: _weights[a.id] ?? a.targetWeight
          };
          final result = RebalanceService.calculate(
            assets,
            _mode,
            RebalanceOptions(
              additionalInvestment: _additional,
              targetWeightOverrides: overrides,
              roundingUnit: settings.roundingUnit,
              feeRate: settings.feeRate,
            ),
          );

          final weightSum = RebalanceService.targetWeightSum(assets,
              overrides: overrides);
          final riskWeight = RebalanceService.riskAssetTargetWeight(assets,
              overrides: overrides);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildModeSelector(),
              const SizedBox(height: 12),
              _buildInvestInput(),
              const SizedBox(height: 16),
              _buildWeightEditor(assets, weightSum, riskWeight, settings),
              const SizedBox(height: 8),
              if (result.warnings.isNotEmpty)
                ...result.warnings.map((w) => _warningBanner(w)),
              const SizedBox(height: 8),
              _buildResultTable(result),
              const SizedBox(height: 16),
              _buildBeforeAfterCharts(result),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('이 거래를 이력에 반영'),
                onPressed: result.lines.any((l) => l.delta != 0)
                    ? () => _applyToHistory(result)
                    : null,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<RebalanceMode>(
      segments: const [
        ButtonSegment(
            value: RebalanceMode.full,
            label: Text('전체 재배분'),
            icon: Icon(Icons.sync_alt)),
        ButtonSegment(
            value: RebalanceMode.buyOnly,
            label: Text('추가금 매수만'),
            icon: Icon(Icons.add_shopping_cart)),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  Widget _buildInvestInput() {
    return TextField(
      controller: _investCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [_ThousandsFormatter()],
      decoration: const InputDecoration(
        labelText: '추가 투자금액 (원)',
        prefixText: '₩ ',
        border: OutlineInputBorder(),
        helperText: '0이면 기존 자산만으로 재배분',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildWeightEditor(
    List<Asset> assets,
    double weightSum,
    double riskWeight,
    AppSettings settings,
  ) {
    final balanced = (weightSum - 100).abs() <= 0.1;
    final overCap =
        settings.riskAssetCap != null && riskWeight > settings.riskAssetCap!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('목표 비중 (%)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '합계 ${Fmt.percent(weightSum)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: balanced ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...assets.map((a) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue:
                            (_weights[a.id] ?? a.targetWeight).toStringAsFixed(1),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                            isDense: true, suffixText: '%'),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null) {
                            setState(() => _weights[a.id] = parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (settings.riskAssetCap != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '위험자산 비중 ${Fmt.percent(riskWeight)} / 상한 ${Fmt.percent(settings.riskAssetCap!)}',
                  style: TextStyle(
                    color: overCap ? Colors.red : Colors.grey,
                    fontWeight: overCap ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _warningBanner(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildResultTable(RebalanceResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 36,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('상품')),
              DataColumn(label: Text('현재금액'), numeric: true),
              DataColumn(label: Text('현재%'), numeric: true),
              DataColumn(label: Text('목표%'), numeric: true),
              DataColumn(label: Text('구분')),
              DataColumn(label: Text('거래금액'), numeric: true),
              DataColumn(label: Text('거래후'), numeric: true),
            ],
            rows: [
              for (final l in result.lines)
                DataRow(cells: [
                  DataCell(SizedBox(width: 110, child: Text(l.name, overflow: TextOverflow.ellipsis))),
                  DataCell(Text(Fmt.number(l.currentValue))),
                  DataCell(Text(Fmt.percent(l.currentWeight))),
                  DataCell(Text(Fmt.percent(l.targetWeight))),
                  DataCell(_actionChip(l.action)),
                  DataCell(Text(
                    l.delta == 0 ? '-' : Fmt.number(l.tradeAmount),
                    style: TextStyle(
                      color: l.delta > 0
                          ? Colors.blue
                          : l.delta < 0
                              ? Colors.red
                              : null,
                    ),
                  )),
                  DataCell(Text(Fmt.number(l.afterValue))),
                ]),
              DataRow(
                color: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest),
                cells: [
                  const DataCell(Text('합계',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(Fmt.number(result.currentTotal))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text('매수 ${Fmt.number(result.totalBuy)}\n매도 ${Fmt.number(result.totalSell)}',
                      style: const TextStyle(fontSize: 11))),
                  DataCell(Text(Fmt.wonSigned(result.netCashFlow))),
                  DataCell(Text(Fmt.number(result.newTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionChip(TradeAction action) {
    Color c;
    switch (action) {
      case TradeAction.buy:
        c = Colors.blue;
        break;
      case TradeAction.sell:
        c = Colors.red;
        break;
      case TradeAction.hold:
        c = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(action.label, style: TextStyle(color: c, fontSize: 12)),
    );
  }

  Widget _buildBeforeAfterCharts(RebalanceResult result) {
    final before = result.lines
        .map((l) => DonutDatum(l.name, l.currentValue))
        .toList();
    final after =
        result.lines.map((l) => DonutDatum(l.name, l.afterValue)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('거래 전 / 거래 후 비중',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Before'),
                      DonutChart(data: before, size: 130),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text('After'),
                      DonutChart(data: after, size: 130),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyToHistory(RebalanceResult result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 반영'),
        content: Text(
            '각 자산의 평가금액을 거래 후 금액으로 갱신하고\n매수/매도 이력을 저장합니다.\n\n매수 합계 ${Fmt.won(result.totalBuy)}\n매도 합계 ${Fmt.won(result.totalSell)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('반영')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(assetProvider.notifier).applyRebalance(result);
    if (mounted) {
      _investCtrl.text = '0';
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거래를 이력에 반영했습니다.')),
      );
    }
  }
}

/// 천 단위 콤마 자동 입력
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '0');
    }
    final n = int.parse(digits);
    final formatted = Fmt.number(n);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
