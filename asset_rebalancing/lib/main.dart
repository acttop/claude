import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/settings_provider.dart';
import 'screens/main_tab_screen.dart';
import 'services/db_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 웹에서는 sqflite ffi web 팩토리를 설정 (네이티브는 no-op)
  initPlatformDatabase();
  await initializeDateFormatting('ko_KR', null);
  runApp(const ProviderScope(child: AssetRebalancingApp()));
}

class AssetRebalancingApp extends ConsumerWidget {
  const AssetRebalancingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    const seed = Color(0xFF2E7D5B);
    return MaterialApp(
      title: '자산 리밸런싱',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MainTabScreen(),
    );
  }
}
