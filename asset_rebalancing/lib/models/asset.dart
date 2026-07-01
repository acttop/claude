import 'enums.dart';

/// 자산 상품
class Asset {
  final String id;
  final String name;
  final String? ticker;
  final AssetCategory category;
  final double currentValue; // 현재 평가금액(원)
  final double? quantity; // 보유 수량(선택)
  final double? price; // 현재가(선택)
  final double targetWeight; // 목표 비중(%)
  final DateTime updatedAt;

  const Asset({
    required this.id,
    required this.name,
    this.ticker,
    required this.category,
    required this.currentValue,
    this.quantity,
    this.price,
    required this.targetWeight,
    required this.updatedAt,
  });

  Asset copyWith({
    String? id,
    String? name,
    String? ticker,
    AssetCategory? category,
    double? currentValue,
    double? quantity,
    double? price,
    double? targetWeight,
    DateTime? updatedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      ticker: ticker ?? this.ticker,
      category: category ?? this.category,
      currentValue: currentValue ?? this.currentValue,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      targetWeight: targetWeight ?? this.targetWeight,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'ticker': ticker,
        'category': category.name,
        'currentValue': currentValue,
        'quantity': quantity,
        'price': price,
        'targetWeight': targetWeight,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Asset.fromMap(Map<String, dynamic> m) => Asset(
        id: m['id'] as String,
        name: m['name'] as String,
        ticker: m['ticker'] as String?,
        category: AssetCategory.fromString(m['category'] as String?),
        currentValue: (m['currentValue'] as num).toDouble(),
        quantity: (m['quantity'] as num?)?.toDouble(),
        price: (m['price'] as num?)?.toDouble(),
        targetWeight: (m['targetWeight'] as num).toDouble(),
        updatedAt:
            DateTime.tryParse(m['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      );

  /// JSON 내보내기/가져오기용 (toMap과 동일 구조)
  Map<String, dynamic> toJson() => toMap();
  factory Asset.fromJson(Map<String, dynamic> j) => Asset.fromMap(j);
}
