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
      return advanceToToday(
          AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>));
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
    final scheme = ColorScheme.fromSeed(
      seedColor: isDark ? const Color(0xFFF18C5A) : const Color(0xFFC64C2E),
      brightness: brightness,
      surface: isDark ? const Color(0xFF151A1E) : const Color(0xFFFFF8F1),
    );

    final textTheme = ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
        selectedColor: scheme.primaryContainer,
      ),
    );
  }
}
