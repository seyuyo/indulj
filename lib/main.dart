import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/providers.dart';
import 'features/favorites/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const InduljApp(),
    ),
  );
}

class InduljApp extends StatelessWidget {
  const InduljApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Indulj',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF009EE3)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF009EE3),
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
