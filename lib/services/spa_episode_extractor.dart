import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/anime.dart';

/// SPA 网站集数提取器
/// 专门处理 Vue/React 等 SPA 框架的集数链接提取
class SpaEpisodeExtractor {
  /// 从 SPA 详情页提取集数信息
  static Future<List<Episode>> extractEpisodes({
    required String detailUrl,
    required String sourceName,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    developer.log('开始提取 SPA 集数: $detailUrl', name: 'SpaEpisodeExtractor');

    HeadlessInAppWebView? webView;
    final completer = Completer<List<Episode>>();

    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(detailUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ),
        onLoadStop: (controller, url) async {
          developer.log('页面加载完成，等待渲染...', name: 'SpaEpisodeExtractor');
          
          // 等待 JavaScript 渲染
          await Future.delayed(const Duration(seconds: 3));

          try {
            // 执行 JavaScript 提取集数信息
            final result = await controller.evaluateJavascript(source: '''
              (function() {
                const episodes = [];
                
                // 方法1: 查找集数元素
                const episodeElements = document.querySelectorAll('.van-grid-item__text');
                episodeElements.forEach((el, index) => {
                  const title = el.textContent.trim();
                  
                  // 过滤导航菜单
                  const navKeywords = ['首页', '目录', '推荐', '更新', '排行榜', '分类', '搜索'];
                  if (navKeywords.includes(title)) return;
                  
                  // 只保留集数
                  if (/第\\d+[话集]|EP?\\d+/i.test(title)) {
                    episodes.push({
                      title: title,
                      index: episodes.length + 1
                    });
                  }
                });
                
                return JSON.stringify(episodes);
              })();
            ''');

            if (result != null) {
              final episodes = _parseEpisodesFromJson(result.toString(), detailUrl, sourceName);
              if (!completer.isCompleted) {
                completer.complete(episodes);
              }
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError('提取集数失败: $e');
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          if (!completer.isCompleted) {
            completer.completeError('页面加载失败: $message');
          }
        },
      );

      await webView.run();

      final episodes = await completer.future.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('提取集数超时');
        },
      );

      developer.log('成功提取 ${episodes.length} 集', name: 'SpaEpisodeExtractor');
      return episodes;
    } finally {
      if (webView != null) {
        await webView.dispose();
      }
    }
  }

  /// 解析 JSON 结果
  static List<Episode> _parseEpisodesFromJson(
    String jsonStr,
    String detailUrl,
    String sourceName,
  ) {
    try {
      final List<dynamic> data = json.decode(jsonStr);
      final episodes = <Episode>[];

      // 从详情页 URL 提取 ID
      final id = _extractIdFromUrl(detailUrl);

      for (final item in data) {
        final title = item['title'] as String;
        final index = item['index'] as int;

        // 构造播放 URL
        String playUrl = '';
        
        if (id.isNotEmpty) {
          // URL 格式: #/play/动漫ID/线路ID/集数
          // 默认使用线路 1
          if (detailUrl.contains('#/detail/')) {
            final baseUrl = detailUrl.split('#/detail/').first;
            playUrl = '$baseUrl#/play/$id/1/$index';  // 线路1
          } else if (detailUrl.contains('/detail/')) {
            final baseUrl = detailUrl.split('/detail/').first;
            playUrl = '$baseUrl/play/$id/1/$index';  // 线路1
          }
        }

        episodes.add(Episode(
          id: '${sourceName}_ep_$index',
          title: title,
          videoUrl: playUrl,
          episodeNumber: index,
          thumbnail: '',
          duration: const Duration(minutes: 24),
        ));
      }

      return episodes;
    } catch (e) {
      developer.log('解析集数 JSON 失败: $e', name: 'SpaEpisodeExtractor');
      return [];
    }
  }

  /// 从 URL 中提取 ID
  static String _extractIdFromUrl(String url) {
    // 匹配 /detail/20250119 或 #/detail/20250119
    final match = RegExp(r'/detail/(\w+)').firstMatch(url);
    return match?.group(1) ?? '';
  }

  /// 构造播放 URL（备用方法）
  static String constructPlayUrl(String detailUrl, int episodeNumber, {int routeId = 1}) {
    final id = _extractIdFromUrl(detailUrl);
    
    if (id.isEmpty) return '';

    // URL 格式: #/play/动漫ID/线路ID/集数
    if (detailUrl.contains('#/detail/')) {
      final baseUrl = detailUrl.split('#/detail/').first;
      return '$baseUrl#/play/$id/$routeId/$episodeNumber';
    } else if (detailUrl.contains('/detail/')) {
      final baseUrl = detailUrl.split('/detail/').first;
      return '$baseUrl/play/$id/$routeId/$episodeNumber';
    }

    return '';
  }
}
