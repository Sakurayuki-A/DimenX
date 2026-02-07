import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../../models/source_rule.dart';
import 'search_logger.dart';

/// 缓存条目
class _CacheEntry {
  final dom.Document document;
  final DateTime timestamp;

  _CacheEntry(this.document, this.timestamp);

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// 动态 HTML 获取器 - 支持 JavaScript 渲染（优化版）
/// 使用 WebView 执行 JavaScript 并获取渲染后的 HTML
class HtmlFetcherDynamic {
  final SearchLogger logger;
  
  // 结果缓存
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _cacheMaxAge = Duration(minutes: 2); // 缓存2分钟
  
  // 并发控制
  static int _activeRequests = 0;
  static const int _maxConcurrent = 2; // 最多同时2个请求
  static final List<Completer<void>> _waitQueue = [];

  HtmlFetcherDynamic({required this.logger});

  /// 等待并发槽位
  Future<void> _acquireConcurrentSlot() async {
    if (_activeRequests >= _maxConcurrent) {
      final completer = Completer<void>();
      _waitQueue.add(completer);
      await completer.future;
    }
    _activeRequests++;
  }

  /// 释放并发槽位
  void _releaseConcurrentSlot() {
    _activeRequests--;
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeAt(0);
      completer.complete();
    }
  }

  /// 清理过期缓存
  static void _cleanupCache() {
    _cache.removeWhere((key, entry) => entry.isExpired(_cacheMaxAge));
  }

  /// 获取动态渲染的搜索页面（优化版）
  Future<dom.Document> fetchSearchPage(
    String keyword,
    SourceRule rule, {
    Duration timeout = const Duration(seconds: 15), // 减少超时时间
    Duration waitAfterLoad = const Duration(seconds: 3), // 减少等待时间
  }) async {
    final searchUrl = rule.searchURL.replaceAll(
      '@keyword',
      Uri.encodeComponent(keyword),
    );

    // 检查缓存
    _cleanupCache();
    if (_cache.containsKey(searchUrl)) {
      final entry = _cache[searchUrl]!;
      if (!entry.isExpired(_cacheMaxAge)) {
        logger.info('📦 使用缓存结果: $searchUrl');
        return entry.document;
      }
      _cache.remove(searchUrl);
    }

    // 等待并发槽位
    await _acquireConcurrentSlot();

    HeadlessInAppWebView? webView;
    try {
      logger.info('🌐 请求动态页面: $searchUrl');

      final completer = Completer<String>();
      bool shouldStopLoading = false;

      // 创建新的 WebView（每次都创建新的，因为回调需要在创建时设置）
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(searchUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useOnLoadResource: false,
          useShouldInterceptRequest: false,
          cacheEnabled: true,
          clearCache: false,
          // 性能优化设置
          mediaPlaybackRequiresUserGesture: true,
          disableContextMenu: true,
          supportZoom: false,
          // 禁用不必要的功能
          javaScriptCanOpenWindowsAutomatically: false,
          allowsInlineMediaPlayback: false,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ),
        // 拦截资源请求，阻止图片、CSS、字体等加载
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url.toString();
          // 只允许主页面和 JS 文件加载
          if (url == searchUrl || url.endsWith('.js')) {
            return NavigationActionPolicy.ALLOW;
          }
          return NavigationActionPolicy.CANCEL;
        },
        onLoadStop: (controller, url) async {
          if (completer.isCompleted) return;

          logger.info('📄 页面加载完成，快速检测渲染状态...');

          // 更激进的智能等待：更快的检测间隔和更少的等待次数
          bool isReady = false;
          int attempts = 0;
          const maxAttempts = 6; // 最多3秒
          int lastContentLength = 0;
          int stableCount = 0;

          while (!isReady && attempts < maxAttempts && !shouldStopLoading) {
            attempts++;
            await Future.delayed(const Duration(milliseconds: 500));

            try {
              // 检查页面内容长度
              final result = await controller.evaluateJavascript(
                source: 'document.body.innerText.length',
              );

              final contentLength = int.tryParse(result?.toString() ?? '0') ?? 0;

              // 如果内容长度稳定（连续2次相同）或内容足够多，认为渲染完成
              if (contentLength > 100) {
                if (contentLength == lastContentLength) {
                  stableCount++;
                  if (stableCount >= 1) {  // 只需要1次稳定即可
                    isReady = true;
                    logger.success('✓ 页面渲染完成 (${attempts * 0.5}秒)');
                  }
                } else if (contentLength > 1000) {
                  // 内容足够多，直接认为完成
                  isReady = true;
                  logger.success('✓ 页面内容充足，渲染完成 (${attempts * 0.5}秒)');
                } else {
                  stableCount = 0;
                }
                lastContentLength = contentLength;
              }
            } catch (e) {
              // 忽略检测错误
            }
          }

          if (!isReady && !shouldStopLoading) {
            logger.warning('⚠ 达到最大等待时间 (${maxAttempts * 0.5}秒)，继续处理');
          }

          try {
            // 获取渲染后的 HTML
            final html = await controller.evaluateJavascript(
              source: 'document.documentElement.outerHTML',
            );

            if (html != null && !completer.isCompleted) {
              final htmlStr = html.toString();
              logger.success('✓ 获取动态 HTML 成功，长度: ${htmlStr.length}');
              shouldStopLoading = true;
              
              // 停止页面加载，节省资源
              try {
                await controller.stopLoading();
              } catch (e) {
                // 忽略停止加载错误
              }
              
              completer.complete(htmlStr);
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError('获取 HTML 失败: $e');
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          logger.error('页面加载错误: $message (code: $code)');
          if (!completer.isCompleted) {
            completer.completeError('页面加载失败: $message');
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          // 只记录错误信息，减少日志输出
          if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
            developer.log(
              '[WebView Error] ${consoleMessage.message}',
              name: 'HtmlFetcherDynamic',
            );
          }
        },
      );

      // 启动 WebView
      await webView.run();

      // 等待结果或超时
      final html = await completer.future.timeout(
        timeout,
        onTimeout: () {
          shouldStopLoading = true;
          throw TimeoutException('获取页面超时 (${timeout.inSeconds}秒)');
        },
      );

      // 解析结果
      final document = html_parser.parse(html);
      
      // 只缓存有效结果（内容足够多）
      final bodyText = document.body?.text.trim() ?? '';
      if (bodyText.length > 200) {
        // 内容足够，可以缓存
        _cache[searchUrl] = _CacheEntry(document, DateTime.now());
        logger.info('✓ 结果已缓存 (内容长度: ${bodyText.length})');
      } else {
        // 内容太少，可能是空结果或错误页面，不缓存
        logger.warning('⚠ 内容过少 (${bodyText.length} 字符)，不缓存此结果');
      }

      return document;
    } finally {
      // 清理 WebView
      if (webView != null) {
        await webView.dispose();
      }
      _releaseConcurrentSlot();
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    // 实例级别无需清理
  }

  /// 清理所有缓存（应用退出时调用）
  static Future<void> disposeAll() async {
    _cache.clear();
    _waitQueue.clear();
    _activeRequests = 0;
  }
}
