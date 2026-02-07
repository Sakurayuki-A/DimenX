import 'package:flutter/widgets.dart';
import 'bangumi_api_service.dart';
import 'bangumi_comment_service.dart';

/// 应用生命周期管理服务
class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isInitialized = false;

  /// 初始化生命周期监听
  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      print('应用生命周期监听已初始化');
    }
  }

  /// 清理生命周期监听
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      print('应用生命周期监听已清理');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('应用恢复前台');
        // 不清理缓存，保持数据
        break;
        
      case AppLifecycleState.paused:
        print('应用进入后台（窗口最小化）');
        // 不清理任何资源，保持播放器运行
        break;
        
      case AppLifecycleState.detached:
        print('应用即将退出');
        // 只在真正退出时清理所有缓存
        _cleanupOnExit();
        break;
        
      case AppLifecycleState.inactive:
        print('应用失去焦点（可能是切换窗口）');
        // 不清理任何资源
        break;
        
      case AppLifecycleState.hidden:
        print('应用被隐藏');
        // 不清理任何资源
        break;
    }
  }

  /// 程序退出时的清理工作
  void _cleanupOnExit() {
    print('执行程序退出清理...');
    
    // 清理BangumiAPI缓存
    BangumiApiService.clearAllCache();
    
    // 清理评论服务缓存
    BangumiCommentService.clearAllCache();
    
    // 可以在这里添加其他需要清理的资源
    // 例如：数据库连接、网络连接等
    
    print('程序退出清理完成');
  }

  /// 手动触发退出清理（用于程序主动退出时）
  void onAppExit() {
    _cleanupOnExit();
    dispose();
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    final bangumiStats = BangumiApiService.getCacheStats();
    return {
      'bangumi': bangumiStats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
