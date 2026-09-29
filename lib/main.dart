import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dompetku_port/app_data.dart';
import 'package:dompetku_port/data/db/app_database.dart';
import 'package:dompetku_port/features/settings/settings_controller.dart';
import 'package:dompetku_port/features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();
  runApp(DompetKuApp(data: AppData(db), prefs: prefs));
}

/// Akar aplikasi DompetKu 2.0 (Flutter).
///
/// [data] & [prefs] bisa disuntikkan oleh widget test (DB in-memory).
class DompetKuApp extends StatefulWidget {
  const DompetKuApp({super.key, required this.data, required this.prefs});

  final AppData data;
  final SharedPreferences prefs;

  @override
  State<DompetKuApp> createState() => _DompetKuAppState();
}

class _DompetKuAppState extends State<DompetKuApp> {
  late final ThemePrefs _theme = ThemePrefs(widget.prefs);
  late final SettingsController _settings =
      SettingsController(widget.data, _theme);

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => AppScope(
        data: widget.data,
        child: MaterialApp(
          title: 'DompetKu',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: _theme.themeMode,
          home: MainShell(data: widget.data, settings: _settings),
        ),
      ),
    );
  }

  /// Tema Material 3; seed = warna primary Android (`colors.xml` → #0F766E).
  ///
  /// Transisi antar-layar adaptif per platform (PHASE 8):
  /// Android = zoom (gaya Material), iOS/macOS = Cupertino slide.
  ThemeData _buildTheme(Brightness brightness) => buildAppTheme(brightness);
}

/// Tema resmi DompetKu — dipakai [DompetKuApp] dan golden test.
///
/// - `inputDecorationTheme`: outline radius 12dp (paritas `TextInputLayout`).
/// - `cardTheme`: radius 16dp (paritas `card_radius`).
ThemeData buildAppTheme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFF0F766E),
      // Paritas `TextInputLayout` Android: outline radius 12dp.
      inputDecorationTheme: InputDecorationThemeData(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Paritas `card_radius` (dimens.xml): 16dp.
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
