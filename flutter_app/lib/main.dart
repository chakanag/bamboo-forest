import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/timeline_screen.dart';
import 'theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  
  runApp(
    const ProviderScope(
      child: BambooForestApp(),
    ),
  );
}

class BambooForestApp extends StatelessWidget {
  const BambooForestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anonymous Bamboo Forest',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const TimelineScreen(),
    );
  }
}
