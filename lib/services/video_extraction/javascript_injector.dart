import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'extraction_logger.dart';

/// JavaScript注入管理器
class JavaScriptInjector {
  final ExtractionLogger logger;
  
  // 缓存加载的脚本
  String? _antiDebugScript;
  String? _videoMonitorScript;

  JavaScriptInjector({required this.logger});

  /// 注入反调试系统
  Future<void> injectAntiDebugSystem(InAppWebViewController controller) async {
    logger.info('注入反调试系统');
    
    try {
      _antiDebugScript ??= await _loadScript('lib/services/video_extraction/scripts/anti_debug.js');
      await controller.evaluateJavascript(source: _antiDebugScript!);
      logger.success('反调试系统注入成功');
    } catch (e) {
      logger.error('反调试系统注入失败: $e');
    }
  }

  /// 注入视频监听脚本
  Future<void> injectVideoMonitor(InAppWebViewController controller) async {
    logger.info('注入视频监听脚本');
    
    try {
      _videoMonitorScript ??= await _loadScript('lib/services/video_extraction/scripts/video_monitor.js');
      await controller.evaluateJavascript(source: _videoMonitorScript!);
      logger.success('视频监听脚本注入成功');
    } catch (e) {
      logger.error('视频监听脚本注入失败: $e');
    }
  }

  /// 注入用户行为模拟脚本
  Future<void> injectUserBehavior(InAppWebViewController controller) async {
    logger.debug('模拟用户行为');
    
    const script = '''
      (function() {
        // 模拟鼠标移动
        document.dispatchEvent(new MouseEvent('mousemove', {
          bubbles: true,
          clientX: 100,
          clientY: 100
        }));
        
        // 模拟页面滚动
        window.scrollTo(0, 100);
        setTimeout(() => window.scrollTo(0, 0), 500);
        
        // 模拟点击
        document.body.dispatchEvent(new MouseEvent('click', {
          bubbles: true
        }));
        
        return true;
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
      logger.debug('用户行为模拟完成');
    } catch (e) {
      logger.error('用户行为模拟失败: $e');
    }
  }

  /// 触发视频播放
  Future<void> triggerVideoPlay(InAppWebViewController controller) async {
    logger.debug('尝试触发视频播放');
    
    const script = '''
      (function() {
        // 查找并点击播放按钮
        const playSelectors = [
          '.play-btn', '.play-button', '.btn-play',
          '[class*="play"]', '[id*="play"]'
        ];
        
        let clicked = false;
        for (const selector of playSelectors) {
          const buttons = document.querySelectorAll(selector);
          for (const button of buttons) {
            if (button.offsetParent !== null) {
              button.click();
              clicked = true;
              break;
            }
          }
          if (clicked) break;
        }
        
        // 尝试直接播放video元素
        document.querySelectorAll('video').forEach(video => {
          video.play().catch(() => {});
        });
        
        return clicked;
      })();
    ''';

    try {
      final result = await controller.evaluateJavascript(source: script);
      logger.debug('播放触发结果: $result');
    } catch (e) {
      logger.error('播放触发失败: $e');
    }
  }

  /// 从assets加载脚本文件
  Future<String> _loadScript(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (e) {
      logger.error('加载脚本文件失败: $path, $e');
      rethrow;
    }
  }
}
