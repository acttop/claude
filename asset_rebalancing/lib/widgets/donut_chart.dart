import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/format_utils.dart';

class DonutDatum {
  final String label;
  final double value;
  const DonutDatum(this.label, this.value);
}

/// 자산 구성 도넛 차트 + 범례
class DonutChart extends StatelessWidget {
  final List<DonutDatum> data;
  final String centerLabel;
  final double size;

  const DonutChart({
    super.key,
    required this.data,
    this.centerLabel = '',
    this.size = 160,
  });

  static const _palette = [
    Color(0xFF2E7D5B),
    Color(0xFF4F86C6),
    Color(0xFFE8A33D),
    Color(0xFFC65B5B),
    Color(0xFF8E6FB0),
    Color(0xFF54A0A8),
    Color(0xFFB0843D),
    Color(0xFF7A8B99),
  ];

  Color colorAt(int i) => _palette[i % _palette.length];

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, d) => s + d.value);
    if (total <= 0) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('데이터 없음')),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: size * 0.28,
                  sections: [
                    for (var i = 0; i < data.length; i++)
                      PieChartSectionData(
                        value: data[i].value,
                        color: colorAt(i),
                        radius: size * 0.20,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              if (centerLabel.isNotEmpty)
                Text(centerLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < data.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, color: colorAt(i)),
                  const SizedBox(width: 4),
                  Text(
                    '${data[i].label} ${Fmt.percent(data[i].value / total * 100)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
