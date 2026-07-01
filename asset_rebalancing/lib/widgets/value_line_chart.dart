import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// (시각, 값) 시계열 라인 차트
class ValueLineChart extends StatelessWidget {
  final List<MapEntry<DateTime, double>> points;
  final double height;

  const ValueLineChart({super.key, required this.points, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('추이를 그리기엔 데이터가 부족합니다 (2개 이상 필요)')),
      );
    }
    final sorted = [...points]..sort((a, b) => a.key.compareTo(b.key));
    final spots = <FlSpot>[];
    for (var i = 0; i < sorted.length; i++) {
      spots.add(FlSpot(i.toDouble(), sorted[i].value));
    }
    final maxY = sorted.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minY = sorted.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final pad = (maxY - minY) * 0.1 + 1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (v, meta) => Text(
                  '${(v / 10000).round()}만',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (sorted.length / 4).ceil().clamp(1, 999).toDouble(),
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= sorted.length) return const SizedBox();
                  final d = sorted[i].key;
                  return Text('${d.month}/${d.day}',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 2.5,
              color: Theme.of(context).colorScheme.primary,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
