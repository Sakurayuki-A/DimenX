import 'dart:async';
import '../../models/source_rule.dart';
import 'extraction_logger.dart';
import 'url_detector.dart';
import 'javascript_injector.dart';
import 'webview_manager.dart';

/// 视频提取结果
class VideoExtractResult {
  final bool success;
  final List<String> videoUrls;
  final String? error;
  final List<String> logs;

  VideoExtractResult({
    required this.success,
    this.videoUrls = const [],
    this.error,
    this.logs = const [],
  });
}

/// 视频提取器 V2 - 重构版
/// 
/// 职责分离：
/// - ExtractionLogger: 日志管理
/// - UrlDetector: URL检测和验证
/// - JavaScriptInjector: JS脚本注入
/// - WebViewManager: WebView生命周期管理
class VideoExtractorV2 {
  static final VideoExtractorV2 _instance = VideoExtractorV2._internal();
  factory VideoExtractorV2() => _instance;
  VideoExtractorV2._internal();

  bool _isExtracting = false;
  Timer? _timeoutTimer;
  Completer<VideoExtractResult>? _completer;

  final List<String> _capturedUrls = [];
  int _iframeRecursionDepth = 0;
  final int _maxIframeRecursionDepth = 3;

  // 模块化组件 - 改为可空类型
  ExtractionLogger? _logger;
  UrlDetector? _urlDetector;
  JavaScriptInjector? _jsInjector;
  WebViewManager? _webViewManager;

  /// 提取视频链接
  Future<VideoExtractResult> extractVideoUrl(
    String episodeUrl,
    SourceRule rule, {
    bool enableLogging = true,
    bool verboseLogging = false,
  }) async {
    if (_isExtracting) {
      return VideoExtractResult(
        success: false,
        error: '正在进行其他提取任务',
        logs: ['并发提取被阻止'],
      );
    }

    // 初始化模块
    _logger = ExtractionLogger(
      enabled: enableLogging,
      verbose: verboseLogging,
    );
    _urlDetector = UrlDetector(logger: _logger!);
    _jsInjector = JavaScriptInjector(logger: _logger!);
    _webViewManager = WebViewManager(
      logger: _logger!,
      urlDetector: _urlDetector!,
      jsInjector: _jsInjector!,
      onVideoFound: _onVideoFound,
      onLoadComplete: _onLoadComplete, // 添加加载完成回调
    );

    _isExtracting = true;
    _logger!.clear();
    _capturedUrls.clear();
    _iframeRecursionDepth = 0;
    _completer = Completer<VideoExtractResult>();

    try {
      _logger!.info('开始提取视频链接: $episodeUrl');

      // 创建WebView并开始提取
      await _webViewManager!.createWebView(episodeUrl, rule);

      // 设置超时
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!_completer!.isCompleted) {
          _completer!.complete(VideoExtractResult(
            success: false,
            error: '视频链接提取超时',
            logs: _logger?.getLogs() ?? [],
          ));
        }
      });

      final result = await _completer!.future;
      return result;
    } catch (e) {
      _logger?.error('提取过程异常: $e');
      return VideoExtractResult(
        success: false,
        error: '提取失败: $e',
        logs: _logger?.getLogs() ?? [],
      );
    } finally {
      _isExtracting = false;
      await _cleanup();
    }
  }

  /// 页面加载完成回调
  void _onLoadComplete() {
    // 如果已经找到视频，立即完成（减少等待时间）
    if (_capturedUrls.isNotEmpty && !_completer!.isCompleted) {
      // 缩短等待时间到200ms
      Timer(const Duration(milliseconds: 200), () {
        if (!_completer!.isCompleted) {
          _completeExtraction();
        }
      });
    }
  }

  /// 处理发现的视频链接
  void _onVideoFound(String url) {
    if (url.isEmpty || _urlDetector == null || _logger == null) return;

    final cleanUrl = url.replaceAll('&amp;', '&');

    // 避免重复
    if (_capturedUrls.contains(cleanUrl)) return;

    // 检查是否为播放器iframe链接
    if (_urlDetector!.isPlayerIframeUrl(cleanUrl)) {
      _logger!.info('发现播放器iframe链接: $cleanUrl');
      _loadPlayerIframe(cleanUrl);
      return;
    }

    // 提取代理URL中的真实视频链接
    final realUrl = _urlDetector!.extractRealVideoUrl(cleanUrl);
    if (realUrl != null) {
      if (!_capturedUrls.contains(realUrl)) {
        _capturedUrls.add(realUrl);
        _logger!.success('提取真实视频: ${_truncateUrl(realUrl)}');
        
        // 立即尝试提前完成
        _tryEarlyComplete();
      }
      return;
    }

    // 处理直接的视频链接
    if (_urlDetector!.isVideoUrl(cleanUrl)) {
      _capturedUrls.add(cleanUrl);
      _logger!.success('捕获视频链接: ${_truncateUrl(cleanUrl)}');
      
      // 立即尝试提前完成
      _tryEarlyComplete();
    }
  }

  /// 尝试提前完成（发现视频链接后）
  void _tryEarlyComplete() {
    if (_completer != null && !_completer!.isCompleted && _logger != null) {
      // 缩短延迟到100ms，快速完成
      Timer(const Duration(milliseconds: 100), () {
        if (_completer != null && !_completer!.isCompleted) {
          _logger?.info('发现视频链接，快速完成提取');
          _completeExtraction();
        }
      });
    }
  }

  /// 递归加载播放器iframe
  Future<void> _loadPlayerIframe(String iframeUrl) async {
    if (_iframeRecursionDepth >= _maxIframeRecursionDepth) {
      _logger?.warning('已达到最大iframe递归深度');
      return;
    }

    _iframeRecursionDepth++;
    _logger?.info('加载播放器iframe (深度: $_iframeRecursionDepth/$_maxIframeRecursionDepth)');

    try {
      await _webViewManager?.loadUrl(iframeUrl);
      await Future.delayed(const Duration(seconds: 5));

      // 检查是否找到视频
      if (_capturedUrls.isNotEmpty && !_completer!.isCompleted) {
        Timer(const Duration(seconds: 2), () {
          if (!_completer!.isCompleted) {
            _completeExtraction();
          }
        });
      }
    } catch (e) {
      _logger?.error('加载播放器iframe失败: $e');
    }
  }

  /// 完成提取
  void _completeExtraction() {
    if (_completer == null || _completer!.isCompleted) return;

    _logger?.success('提取完成，找到 ${_capturedUrls.length} 个视频链接');
    final prioritizedUrls = _urlDetector?.prioritizeUrls(List.from(_capturedUrls)) ?? [];

    _completer!.complete(VideoExtractResult(
      success: true,
      videoUrls: prioritizedUrls,
      logs: _logger?.getLogs() ?? [],
    ));
  }

  /// 清理资源
  Future<void> _cleanup() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    
    if (_webViewManager != null) {
      await _webViewManager!.dispose();
      _webViewManager = null;
    }
    
    // 清空模块引用
    _logger = null;
    _urlDetector = null;
    _jsInjector = null;
    
    _capturedUrls.clear();
  }

  /// 停止提取
  Future<void> stopExtraction() async {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(VideoExtractResult(
        success: false,
        error: '用户取消提取',
        logs: _logger?.getLogs() ?? [],
      ));
    }
    await _cleanup();
  }

  /// 截断URL用于显示
  String _truncateUrl(String url, {int maxLength = 80}) {
    return url.length > maxLength ? '${url.substring(0, maxLength)}...' : url;
  }
}
