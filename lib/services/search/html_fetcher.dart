import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../../models/source_rule.dart';
import 'search_logger.dart';

/// 缓存条目
class _StaticCacheEntry {
  final dom.Document document;
  final DateTime timestamp;

  _StaticCacheEntry(this.document, this.timestamp);

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }
}

/// HTTP 请求层 - 单一职责：获取和解析 HTML（带缓存）
class HtmlFetcher {
  final SearchLogger logger;

  // 结果缓存
  static final Map<String, _StaticCacheEntry> _cache = {};
  static const Duration _cacheMaxAge = Duration(minutes: 2); // 缓存2分钟

  const HtmlFetcher({required this.logger});

  /// 清理过期缓存
  static void _cleanupCache() {
    _cache.removeWhere((key, entry) => entry.isExpired(_cacheMaxAge));
  }

  /// 获取搜索页面 HTML（带缓存）
  Future<dom.Document> fetchSearchPage(String keyword, SourceRule rule) async {
    final searchUrl = rule.searchURL.replaceAll('@keyword', Uri.encodeComponent(keyword));

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

    logger.info('请求搜索页面: $searchUrl');

    final response = await http.get(
      Uri.parse(searchUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP 请求失败: ${response.statusCode}');
    }

    logger.success('页面获取成功，长度: ${response.body.length}');
    
    // 解析结果
    final document = html_parser.parse(response.body);
    
    // 只缓存有效结果（内容足够多）
    final bodyText = document.body?.text.trim() ?? '';
    if (bodyText.length > 200) {
      // 内容足够，可以缓存
      _cache[searchUrl] = _StaticCacheEntry(document, DateTime.now());
      logger.info('✓ 结果已缓存 (内容长度: ${bodyText.length})');
    } else {
      // 内容太少，可能是空结果或错误页面，不缓存
      logger.warning('⚠ 内容过少 (${bodyText.length} 字符)，不缓存此结果');
    }
    
    return document;
  }

  /// 清理所有缓存
  static void clearCache() {
    _cache.clear();
  }
}
