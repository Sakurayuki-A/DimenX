import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData get themeData => _defaultTheme;

  static final ThemeData _defaultTheme = ThemeData(
    primarySwatch: Colors.blueGrey,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
    fontFamily: 'Microsoft YaHei',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Microsoft YaHei',
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 4,
      shadowColor: Colors.black26,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      displayMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      displaySmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      headlineLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      headlineMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      headlineSmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      titleLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      titleMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      titleSmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      bodyLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w400, color: Color(0xFFE0E0E0)),
      bodyMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w400, color: Color(0xFFE0E0E0)),
      bodySmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w400, color: Color(0xFFB0B0B0)),
      labelLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Colors.white),
      labelMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFFE0E0E0)),
      labelSmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFFB0B0B0)),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF008080),
      secondary: Color(0xFF26A69A),
      surface: Color(0xFF1E1E1E),
      background: Color(0xFF121212),
      error: Colors.redAccent,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onBackground: Colors.white,
      onError: Colors.white,
    ),
  );
}
