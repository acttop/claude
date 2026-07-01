import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱 설정 (테마, 수수료율, 거래단위, 위험자산 상한)
class AppSettings {
  final ThemeMode themeMode;
  final double feeRate; // 0.0015 = 0.15%
  final int? roundingUnit; // 1000 등. null이면 반올림 안 함
  final double? riskAssetCap; // 위험자산 비중 상한 %. null이면 미적용

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.feeRate = 0,
    this.roundingUnit,
    this.riskAssetCap,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? feeRate,
    int? roundingUnit,
    bool clearRoundingUnit = false,
    double? riskAssetCap,
    bool clearRiskCap = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      feeRate: feeRate ?? this.feeRate,
      roundingUnit: clearRoundingUnit ? null : (roundingUnit ?? this.roundingUnit),
      riskAssetCap: clearRiskCap ? null : (riskAssetCap ?? this.riskAssetCap),
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setThemeMode(ThemeMode mode) =>
      state = state.copyWith(themeMode: mode);
  void setFeeRate(double rate) => state = state.copyWith(feeRate: rate);
  void setRoundingUnit(int? unit) => state = unit == null
      ? state.copyWith(clearRoundingUnit: true)
      : state.copyWith(roundingUnit: unit);
  void setRiskCap(double? cap) => state = cap == null
      ? state.copyWith(clearRiskCap: true)
      : state.copyWith(riskAssetCap: cap);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
