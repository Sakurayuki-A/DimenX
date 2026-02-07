import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeProvider with ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.dark;
  
  AppThemeMode get themeMode => _themeMode;
  
  ThemeData get themeData {
    switch (_themeMode) {
      case AppThemeMode.light:
        return _lightTheme;
      case AppThemeMode.dark:
        return _darkTheme;
      case AppThemeMode.system:
        // 系统模式下，默认返回深色主题
        // 实际应用中会根据系统设置动态切换
        return _darkTheme;
    }
  }
  
  ThemeProvider() {
    _loadThemeMode();
  }
  
  /// 从本地存储加载主题模式
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeString = prefs.getString('theme_mode') ?? 'dark';
      _themeMode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == themeModeString,
        orElse: () => AppThemeMode.dark,
      );
      notifyListeners();
    } catch (e) {
      print('加载主题模式失败: $e');
    }
  }
  
  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (e) {
      print('保存主题模式失败: $e');
    }
  }
  
  /// 切换到浅色模式
  Future<void> setLightMode() => setThemeMode(AppThemeMode.light);
  
  /// 切换到深色模式
  Future<void> setDarkMode() => setThemeMode(AppThemeMode.dark);
  
  /// 切换到跟随系统
  Future<void> setSystemMode() => setThemeMode(AppThemeMode.system);

  // 深色主题
  static final ThemeData _darkTheme = ThemeData(
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
  
  // 浅色主题
  static final ThemeData _lightTheme = ThemeData(
    primarySwatch: Colors.teal,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    cardColor: Colors.white,
    fontFamily: 'Microsoft YaHei',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF008080),
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
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      displayMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      displaySmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      headlineLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      headlineMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      headlineSmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      titleLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      titleMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF424242)),
      titleSmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF424242)),
      bodyLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w400, color: Color(0xFF424242)),
      bodyMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w400, color: Color(0xFF616161)),
      bodySmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w400, color: Color(0xFF757575)),
      labelLarge: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF212121)),
      labelMedium: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF424242)),
      labelSmall: TextStyle(fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w500, color: Color(0xFF757575)),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF008080),
      secondary: Color(0xFF26A69A),
      surface: Colors.white,
      background: Color(0xFFF5F5F5),
      error: Colors.red,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF212121),
      onBackground: Color(0xFF212121),
      onError: Colors.white,
    ),
  );
}
