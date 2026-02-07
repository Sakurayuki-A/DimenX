import 'package:html/dom.dart' as dom;
import '../../models/source_rule.dart';
import 'html_fetcher.dart';
import 'html_fetcher_dynamic.dart';
import 'search_logger.dart';

/// 混合 HTML 获取器 - 自动选择静态或动态加载
class HtmlFetcherHybrid {
  final SearchLogger logger;
  final HtmlFetcher _staticFetcher;
  final HtmlFetcherDynamic _dynamicFetcher;

  HtmlFetcherHybrid({required this.logger})
      : _staticFetcher = HtmlFetcher(logger: logger),
        _dynamicFetcher = HtmlFetcherDynamic(logger: logger);

  /// 获取搜索页面 - 自动选择最佳方式
  Future<dom.Document> fetchSearchPage(
    String keyword,
    SourceRule rule, {
    bool forceDynamic = false,
    bool autoFallback = true,
  }) async {
    // 检查规则配置或强制动态加载
    final needsDynamic = forceDynamic || rule.enableDynamicLoading || _needsDynamicLoading(rule);

    if (needsDynamic) {
      logger.info('🔄 使用动态加载模式 (${forceDynamic ? "强制" : rule.enableDynamicLoading ? "规则配置" : "自动检测"})');
      try {
        return await _dynamicFetcher.fetchSearchPage(keyword, rule);
      } catch (e) {
        if (autoFallback) {
          logger.warning('动态加载失败，回退到静态加载: $e');
          return await _staticFetcher.fetchSearchPage(keyword, rule);
        }
        rethrow;
      }
    } else {
      logger.info('⚡ 使用静态加载模式');
      try {
        final doc = await _staticFetcher.fetchSearchPage(keyword, rule);
        
        // 检测是否需要动态加载
        if (autoFallback && _isEmptyOrSPA(doc)) {
          logger.warning('检测到空内容或 SPA，切换到动态加载');
          return await _dynamicFetcher.fetchSearchPage(keyword, rule);
        }
        
        return doc;
      } catch (e) {
        if (autoFallback) {
          logger.warning('静态加载失败，尝试动态加载: $e');
          return await _dynamicFetcher.fetchSearchPage(keyword, rule);
        }
        rethrow;
      }
    }
  }

  /// 判断是否需要动态加载
  bool _needsDynamicLoading(SourceRule rule) {
    final url = rule.searchURL.toLowerCase();
    
    // 已知需要动态加载的网站特征
    final dynamicPatterns = [
      'agedm.io',      // AGE 动漫
      'vue',           // Vue.js 应用
      'react',         // React 应用
      'angular',       // Angular 应用
      '#/',            // SPA 路由特征
      'spa',           // SPA 标识
    ];

    for (final pattern in dynamicPatterns) {
      if (url.contains(pattern)) {
        return true;
      }
    }

    // 检查规则中的标记
    if (rule.searchURL.contains('#') && rule.searchURL.contains('/')) {
      return true;  // 可能是 SPA 路由
    }

    return false;
  }

  /// 检测是否是空内容或 SPA
  bool _isEmptyOrSPA(dom.Document doc) {
    // 检查 body 是否几乎为空
    final bodyText = doc.body?.text.trim() ?? '';
    if (bodyText.length < 200) {  // 提高阈值到200，与缓存逻辑一致
      return true;
    }

    // 检查是否有 SPA 框架的特征
    final html = doc.outerHtml.toLowerCase();
    final spaIndicators = [
      'id="app"',
      'id="root"',
      'ng-app',
      'data-reactroot',
      'v-cloak',
    ];

    for (final indicator in spaIndicators) {
      if (html.contains(indicator)) {
        // 如果有 SPA 标识但内容很少，说明需要 JS 渲染
        if (bodyText.length < 500) {
          return true;
        }
      }
    }

    return false;
  }

  /// 清理资源
  Future<void> dispose() async {
    await _dynamicFetcher.dispose();
  }
}
