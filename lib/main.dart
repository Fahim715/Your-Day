// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic.dart';
import 'models.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(YourDayApp(prefs: prefs));
}

class YourDayApp extends StatefulWidget {
  final SharedPreferences prefs;
  const YourDayApp({super.key, required this.prefs});

  @override
  State<YourDayApp> createState() => _YourDayAppState();
}

class _YourDayAppState extends State<YourDayApp> {
  static const _key = 'your_day:v1';
  late AppState _state;

  @override
  void initState() {
    super.initState();
    _state = _load();
  }

  AppState _load() {
    try {
      final raw = widget.prefs.getString(_key);
      if (raw == null) return createInitialState();
      return advanceToToday(AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (_) {
      return createInitialState();
    }
  }

  void _save(AppState s) =>
      widget.prefs.setString(_key, jsonEncode(s.toJson()));

  void update(AppState Function(AppState) fn) {
    setState(() {
      _state = fn(advanceToToday(_state));
      _save(_state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your Day',
      debugShowCheckedModeBanner: false,
      themeMode: _state.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(state: _state, onUpdate: update),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFFF8A65) : const Color(0xFFC24E3A),
      onPrimary: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFFFFFFF),
      secondary: isDark ? const Color(0xFF9A8F86) : const Color(0xFF7A6F68),
      onSecondary: isDark ? const Color(0xFF0F1418) : const Color(0xFF2B211B),
      error: const Color(0xFFB3261E),
      onError: const Color(0xFFFFFFFF),
      surface: isDark ? const Color(0xFF181E23) : const Color(0xFFFFF9F4),
      onSurface: isDark ? const Color(0xFFE7E2DC) : const Color(0xFF2B211B),
      background: isDark ? const Color(0xFF0F1418) : const Color(0xFFF7F2EE),
      onBackground: isDark ? const Color(0xFFE7E2DC) : const Color(0xFF2B211B),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    );
  }
}
