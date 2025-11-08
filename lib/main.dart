import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'screens/home_screen.dart';
import 'providers/anime_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/history_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/source_rule_provider.dart';
import 'services/video_extractor.dart';
import 'services/cache_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 设置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
    title: 'DimenX',
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  // 初始化MediaKit
  MediaKit.ensureInitialized();
  
  // 初始化MediaKit Native Event Loop (Windows)
  if (Platform.isWindows) {
    try {
      // 确保native event loop正确初始化
      print('初始化MediaKit Native Event Loop...');
    } catch (e) {
      print('MediaKit Native Event Loop初始化警告: $e');
    }
  }
  
  // 初始化WebView（Windows平台）
  if (Platform.isWindows) {
    print('Windows平台检测，初始化WebView环境...');
    // 新的视频提取器不需要手动COM初始化
    print('WebView环境初始化完成');
  }
  
  runApp(const AnimeHubXApp());
}

class AnimeHubXApp extends StatefulWidget {
  const AnimeHubXApp({super.key});

  @override
  State<AnimeHubXApp> createState() => _AnimeHubXAppState();
}

class _AnimeHubXAppState extends State<AnimeHubXApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用进入后台或退出时清理资源
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) {
      _performGlobalCleanup();
    }
  }
  
  void _performGlobalCleanup() {
    Future.microtask(() async {
      try {
        // 清理缓存
        CacheManager().clearAllCache();
        
        // 清理视频提取器资源
        final extractor = VideoExtractor();
        await extractor.stopExtraction();
        
        print('应用退出：全局资源清理完成');
      } catch (e) {
        print('应用退出：全局资源清理失败: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AnimeProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => SourceRuleProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DimenX',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
