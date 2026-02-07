import 'dart:io';
import 'package:flutter/services.dart';

/// Windows COM资源管理器
class ComResourceManager {
  static const MethodChannel _channel = MethodChannel('com_resource_manager');
  static bool _isInitialized = false;
  static int _initCount = 0;

  /// 初始化COM
  static Future<bool> initializeCOM() async {
    if (!Platform.isWindows) return true;
    
    try {
      _initCount++;
      print('ComResourceManager: 初始化COM (第${_initCount}次)');
      
      // 调用Windows平台代码初始化COM
      final result = await _channel.invokeMethod('initializeCOM');
      _isInitialized = result == true;
      
      if (_isInitialized) {
        print('ComResourceManager: COM初始化成功');
      } else {
        print('ComResourceManager: COM初始化失败');
      }
      
      return _isInitialized;
    } catch (e) {
      print('ComResourceManager: COM初始化异常: $e');
      return false;
    }
  }

  /// 强制释放COM资源
  static Future<void> forceReleaseCOM() async {
    if (!Platform.isWindows) return;
    
    try {
      print('ComResourceManager: 强制释放COM资源');
      await _channel.invokeMethod('forceReleaseCOM');
      _isInitialized = false;
      print('ComResourceManager: COM资源释放完成');
    } catch (e) {
      print('ComResourceManager: COM资源释放失败: $e');
    }
  }

  /// 重置COM环境
  static Future<bool> resetCOM() async {
    if (!Platform.isWindows) return true;
    
    try {
      print('ComResourceManager: 重置COM环境');
      
      // 先释放
      await forceReleaseCOM();
      
      // 等待一段时间
      await Future.delayed(const Duration(milliseconds: 200));
      
      // 重新初始化
      return await initializeCOM();
    } catch (e) {
      print('ComResourceManager: COM重置失败: $e');
      return false;
    }
  }

  /// 检查COM状态
  static Future<bool> checkCOMStatus() async {
    if (!Platform.isWindows) return true;
    
    try {
      final result = await _channel.invokeMethod('checkCOMStatus');
      return result == true;
    } catch (e) {
      print('ComResourceManager: 检查COM状态失败: $e');
      return false;
    }
  }

  /// 获取COM初始化次数
  static int get initializationCount => _initCount;
  
  /// 是否已初始化
  static bool get isInitialized => _isInitialized;
}
