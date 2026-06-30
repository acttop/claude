import 'enums.dart';

/// 자산 변동 이력
class History {
  final String id;
  final String assetId;
  final DateTime date;
  final HistoryType type;
  final double beforeValue;
  final double afterValue;
  final double amount; // 변동 금액(원). 매수 +, 매도 -
  final String? memo;

  const History({
    required this.id,
    required this.assetId,
    required this.date,
    required this.type,
    required this.beforeValue,
    required this.afterValue,
    required this.amount,
    this.memo,
  });

  History copyWith({
    String? id,
    String? assetId,
    DateTime? date,
    HistoryType? type,
    double? beforeValue,
    double? afterValue,
    double? amount,
    String? memo,
  }) {
    return History(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      date: date ?? this.date,
      type: type ?? this.type,
      beforeValue: beforeValue ?? this.beforeValue,
      afterValue: afterValue ?? this.afterValue,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'assetId': assetId,
        'date': date.toIso8601String(),
        'type': type.name,
        'beforeValue': beforeValue,
        'afterValue': afterValue,
        'amount': amount,
        'memo': memo,
      };

  factory History.fromMap(Map<String, dynamic> m) => History(
        id: m['id'] as String,
        assetId: m['assetId'] as String,
        date: DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now(),
        type: HistoryType.fromString(m['type'] as String?),
        beforeValue: (m['beforeValue'] as num).toDouble(),
        afterValue: (m['afterValue'] as num).toDouble(),
        amount: (m['amount'] as num).toDouble(),
        memo: m['memo'] as String?,
      );

  Map<String, dynamic> toJson() => toMap();
  factory History.fromJson(Map<String, dynamic> j) => History.fromMap(j);
}
