/// 자산 카테고리
enum AssetCategory {
  domesticStock('국내주식'),
  foreignStock('해외주식'),
  etf('ETF'),
  bond('채권'),
  cash('현금'),
  etc('기타');

  const AssetCategory(this.label);
  final String label;

  /// 한글 라벨/영문 이름 모두로부터 안전하게 파싱. 알 수 없으면 [etc].
  static AssetCategory fromString(String? raw) {
    if (raw == null) return AssetCategory.etc;
    final v = raw.trim();
    for (final c in AssetCategory.values) {
      if (c.label == v || c.name.toLowerCase() == v.toLowerCase()) return c;
    }
    // 흔한 동의어 보정
    switch (v) {
      case '국내 주식':
      case '한국주식':
        return AssetCategory.domesticStock;
      case '해외 주식':
      case '미국주식':
        return AssetCategory.foreignStock;
      case '예금':
      case '현금성':
        return AssetCategory.cash;
      default:
        return AssetCategory.etc;
    }
  }
}

/// 변동 이력 유형
enum HistoryType {
  buy('매수'),
  sell('매도'),
  weightChange('비중변경'),
  valueUpdate('평가금액갱신'),
  create('신규등록'),
  delete('삭제');

  const HistoryType(this.label);
  final String label;

  static HistoryType fromString(String? raw) {
    if (raw == null) return HistoryType.valueUpdate;
    final v = raw.trim();
    for (final t in HistoryType.values) {
      if (t.label == v || t.name.toLowerCase() == v.toLowerCase()) return t;
    }
    return HistoryType.valueUpdate;
  }
}

/// 리밸런싱 모드
enum RebalanceMode {
  /// 매수·매도 모두 허용해 목표 비중에 정확히 맞춤
  full('전체 재배분'),

  /// 기존 보유분은 팔지 않고 추가 투자금만으로 비중 격차를 줄임
  buyOnly('추가금 매수만');

  const RebalanceMode(this.label);
  final String label;
}
