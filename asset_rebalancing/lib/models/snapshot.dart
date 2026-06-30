import 'dart:convert';

/// 스냅샷 내 자산별 구성 항목
class SnapshotItem {
  final String name;
  final double value;
  final double weight; // %

  const SnapshotItem({
    required this.name,
    required this.value,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'weight': weight,
      };

  factory SnapshotItem.fromJson(Map<String, dynamic> j) => SnapshotItem(
        name: j['name'] as String,
        value: (j['value'] as num).toDouble(),
        weight: (j['weight'] as num).toDouble(),
      );
}

/// 포트폴리오 스냅샷
class Snapshot {
  final String id;
  final DateTime date;
  final double totalValue;
  final List<SnapshotItem> breakdown;

  const Snapshot({
    required this.id,
    required this.date,
    required this.totalValue,
    required this.breakdown,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'totalValue': totalValue,
        // breakdown은 json 문자열로 저장
        'breakdown': jsonEncode(breakdown.map((e) => e.toJson()).toList()),
      };

  factory Snapshot.fromMap(Map<String, dynamic> m) {
    final raw = m['breakdown'];
    final List list = raw is String ? (jsonDecode(raw) as List) : (raw as List);
    return Snapshot(
      id: m['id'] as String,
      date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
      totalValue: (m['totalValue'] as num).toDouble(),
      breakdown: list
          .map((e) => SnapshotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'totalValue': totalValue,
        'breakdown': breakdown.map((e) => e.toJson()).toList(),
      };

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
        id: j['id'] as String,
        date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
        totalValue: (j['totalValue'] as num).toDouble(),
        breakdown: (j['breakdown'] as List)
            .map((e) => SnapshotItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
