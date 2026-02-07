import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../models/source_rule.dart';
import 'extraction_logger.dart';
import 'url_detector.dart';
import 'javascript_injector.dart';

/// WebView管理器
class WebViewManager {
  final ExtractionLogger logger;
  final UrlDetector urlDetector;
  final JavaScriptInjector jsInjector;
  final Function(String) onVideoFound;
  final Function() onLoadComplete; // 添加加载完成回调

  HeadlessInAppWebView? _webView;

  WebViewManager({
    required this.logger,
    required this.urlDetector,
    required this.jsInjector,
    required this.onVideoFound,
    required this.onLoadComplete,
  });

  /// 创建WebView实例
  Future<void> createWebView(String episodeUrl, SourceRule rule) async {
    logger.info('创建WebView实例');

    _webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(episodeUrl),
        headers: _buildHeaders(),
      ),
      initialSettings: _buildSettings(),
      onWebViewCreated: _onWebViewCreated,
      onLoadStart: _onLoadStart,
      onProgressChanged: _onProgressChanged,
      onLoadStop: _onLoadStop,
      onConsoleMessage: _onConsoleMessage,
      shouldInterceptRequest: _shouldInterceptRequest,
      onReceivedError: _onReceivedError,
    );

    await _webView!.run();
    logger.success('WebView运行成功');
  }

  /// 加载URL
  Future<void> loadUrl(String url) async {
    if (_webView == null) {
      logger.error('WebView未初始化');
      return;
    }

    final controller = _webView!.webViewController;
    if (controller == null) {
      logger.error('WebViewController不可用');
      return;
    }

    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
  }

  /// 销毁WebView
  Future<void> dispose() async {
    if (_webView != null) {
      try {
        await _webView!.dispose();
      } catch (e) {
        logger.error('WebView清理失败: $e');
      }
      _webView = null;
    }
  }

  // ===== WebView回调处理 =====

  void _onWebViewCreated(InAppWebViewController controller) {
    logger.debug('WebView已创建');

    // 注册视频链接回调
    controller.addJavaScriptHandler(
      handlerName: 'onVideoFound',
      callback: (args) {
        if (args.isNotEmpty) {
          final url = args[0].toString();
          onVideoFound(url);
        }
      },
    );
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    logger.debug('开始加载页面: ${url?.toString() ?? ""}');
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    logger.debug('页面加载进度: $progress%');
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    logger.info('页面加载完成: ${url?.toString() ?? ""}');

    // 等待页面渲染（减少到500ms）
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // 并行执行注入操作
      await Future.wait([
        jsInjector.injectUserBehavior(controller),
        jsInjector.injectAntiDebugSystem(controller),
        jsInjector.injectVideoMonitor(controller),
      ]);

      // 等待JavaScript执行（减少到1秒）
      await Future.delayed(const Duration(seconds: 1));

      // 解析页面内容
      await _parsePageContent(controller);

      // 尝试触发播放（减少等待时间）
      await Future.delayed(const Duration(milliseconds: 500));
      await jsInjector.triggerVideoPlay(controller);
      
      // 再等待一小段时间让视频链接被捕获（减少到1秒）
      await Future.delayed(const Duration(seconds: 1));
      
      // 通知加载完成
      onLoadComplete();
    } catch (e) {
      // 捕获WebView已释放的错误
      if (e.toString().contains('disposed')) {
        logger.debug('WebView已释放，跳过后续操作');
      } else {
        logger.error('页面加载处理失败: $e');
      }
    }
  }

  void _onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  ) {
    logger.debug('WebView控制台: ${consoleMessage.message}');
  }

  Future<WebResourceResponse?> _shouldInterceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    final url = request.url.toString();

    // 拦截反调试脚本
    if (urlDetector.shouldBlockScript(url)) {
      logger.info('拦截反调试脚本: $url');
      return WebResourceResponse(
        contentType: 'application/javascript',
        data: Uint8List.fromList('// Script blocked by AnimeHUBX'.codeUnits),
      );
    }

    // 检测视频链接（只记录一次）
    if (urlDetector.isVideoUrl(url)) {
      logger.debug('请求拦截器发现视频: $url');
      onVideoFound(url);
    }

    return null;
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    logger.error('页面加载错误: ${error.description}');
  }

  // ===== 页面解析 =====

  Future<void> _parsePageContent(InAppWebViewController controller) async {
    logger.debug('开始解析页面内容');

    const script = '''
      (function() {
        const results = [];
        const html = document.documentElement.outerHTML;
        
        console.log('AnimeHUBX: 开始解析页面内容');
        
        // 正则匹配视频链接（包括字节跳动CDN）
        const patterns = [
          /https?:\\/\\/[^"\\s]+\\.m3u8[^"\\s]*/gi,
          /https?:\\/\\/[^"\\s]+\\.mp4[^"\\s]*/gi,
          /https?:\\/\\/[^"\\s]*mime_type=video[^"\\s]*/gi,
          /https?:\\/\\/[^"\\s]*toutiao[^"\\s]*\\/tos\\/[^"\\s]*/gi, // 字节跳动CDN
          /https?:\\/\\/v\\d+\\.toutiao\\d+\\.com[^"\\s]*\\/tos\\/[^"\\s]*/gi, // toutiao50.com等
        ];
        
        patterns.forEach(pattern => {
          let match;
          while ((match = pattern.exec(html)) !== null) {
            const url = match[0].replace(/['"\\s]/g, '');
            if (url && !url.includes('.jpg') && !url.includes('.png')) {
              console.log('AnimeHUBX: 正则匹配到:', url);
              results.push(url);
            }
          }
        });
        
        // 查找video标签
        document.querySelectorAll('video').forEach(video => {
          if (video.src) {
            console.log('AnimeHUBX: video标签src:', video.src);
            results.push(video.src);
          }
        });
        
        // 查找iframe标签
        const iframes = document.querySelectorAll('iframe');
        console.log('AnimeHUBX: 找到', iframes.length, '个iframe');
        iframes.forEach((iframe, index) => {
          if (iframe.src) {
            console.log('AnimeHUBX: iframe[' + index + '] src:', iframe.src);
            results.push('IFRAME:' + iframe.src); // 标记为iframe链接
          }
        });
        
        console.log('AnimeHUBX: 解析完成，共找到', results.length, '个链接');
        return [...new Set(results)];
      })();
    ''';

    try {
      final result = await controller.evaluateJavascript(source: script);
      if (result is List) {
        for (final url in result) {
          if (url is String) {
            // 检查是否是iframe链接
            if (url.startsWith('IFRAME:')) {
              final iframeUrl = url.substring(7); // 移除 "IFRAME:" 前缀
              logger.info('发现iframe: $iframeUrl');
              if (urlDetector.isPlayerIframeUrl(iframeUrl)) {
                onVideoFound(iframeUrl); // 触发iframe加载
              }
            } else if (urlDetector.isVideoUrl(url)) {
              logger.info('页面解析发现视频: $url');
              onVideoFound(url);
            }
          }
        }
      }
    } catch (e) {
      logger.error('页面解析失败: $e');
    }
  }

  // ===== 配置构建 =====

  Map<String, String> _buildHeaders() {
    return {
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
      'Upgrade-Insecure-Requests': '1',
    };
  }

  InAppWebViewSettings _buildSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      cacheEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      incognito: false,
      hardwareAcceleration: true,
    );
  }
}
