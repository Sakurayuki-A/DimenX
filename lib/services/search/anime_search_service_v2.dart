import 'package:html/dom.dart' as dom;

import '../../models/anime.dart';
import '../../models/source_rule.dart';
import 'html_fetcher.dart';
import 'html_fetcher_hybrid.dart';
import 'node_selector.dart';
import 'node_filter.dart';
import 'title_extractor.dart';
import 'title_validator.dart';
import 'title_normalizer.dart';
import 'result_deduplicator.dart';
import 'series_detector.dart';
import 'search_logger.dart';

/// 重构后的搜索服务 - 清晰的分层架构
/// 
/// 职责分离：
/// - HtmlFetcher: HTTP 请求（静态）
/// - HtmlFetcherHybrid: 混合请求（静态+动态）
/// - NodeSelector: CSS 选择器
/// - NodeFilter: 节点过滤
/// - TitleExtractor: 标题提取
/// - TitleValidator: 标题验证
/// - TitleNormalizer: 标题归一化
/// - ResultDeduplicator: 结果去重
/// - SeriesDetector: 系列作品检测
/// - SearchLogger: 日志管理
class AnimeSearchServiceV2 {
  final HtmlFetcherHybrid _fetcher;
  final NodeSelector _selector;
  final NodeFilter _filter;
  final TitleExtractor _extractor;
  final TitleValidator _validator;
  final TitleNormalizer _normalizer;
  final ResultDeduplicator _deduplicator;
  final SearchLogger _logger;

  AnimeSearchServiceV2({
    bool enableLogging = true,
    bool verboseLogging = false,
    bool useDynamicLoading = true,
  })  : _logger = SearchLogger(
          enabled: enableLogging,
          verbose: verboseLogging,
        ),
        _fetcher = HtmlFetcherHybrid(
          logger: SearchLogger(
            enabled: enableLogging,
            verbose: verboseLogging,
          ),
        ),
        _selector = NodeSelector(
          logger: SearchLogger(
            enabled: enableLogging,
            verbose: verboseLogging,
          ),
        ),
        _filter = NodeFilter(
          logger: SearchLogger(
            enabled: enableLogging,
            verbose: verboseLogging,
          ),
        ),
        _extractor = TitleExtractor(
          logger: SearchLogger(
            enabled: enableLogging,
            verbose: verboseLogging,
          ),
        ),
        _validator = TitleValidator(
          logger: SearchLogger(
            enabled: enableLogging,
            verbose: verboseLogging,
          ),
        ),
        _normalizer = TitleNormalizer(),
        _deduplicator = ResultDeduplicator(
          normalizer: TitleNormalizer(),
          seriesDetector: SeriesDetector(),
          logger: SearchLogger(
            enabled: enableLogging,
            verbose: verboseLogging,
          ),
        );

  /// 搜索动漫（主入口）
  Future<List<Anime>> searchAnimes(
    String keyword,
    List<SourceRule> rules,
  ) async {
    _logger.info('开始搜索: "$keyword", 规则数: ${rules.length}');

    if (rules.isEmpty) {
      _logger.warning('没有配置搜索规则');
      return [];
    }

    final allResults = <Anime>[];

    // 使用每个规则搜索
    for (final rule in rules) {
      try {
        final results = await _searchWithRule(keyword, rule);
        allResults.addAll(results);
        _logger.success('规则 ${rule.name}: ${results.length} 个结果');
      } catch (e) {
        _logger.error('规则 ${rule.name} 失败: $e');
      }
    }

    // 去重和归一化（不合并系列，保留所有版本）
    final deduplicated = _deduplicator.deduplicate(allResults, mergeSeries: false);

    // 按相关性排序
    deduplicated.sort((a, b) {
      final scoreA = _calculateRelevanceScore(a.title, keyword);
      final scoreB = _calculateRelevanceScore(b.title, keyword);
      return scoreB.compareTo(scoreA); // 降序排列
    });
    
    // 输出排序后的结果（调试用）
    _logger.info('📊 相关性排序结果:');
    for (int i = 0; i < deduplicated.length && i < 10; i++) {
      final score = _calculateRelevanceScore(deduplicated[i].title, keyword);
      _logger.info('  ${i + 1}. ${deduplicated[i].title} (评分: ${score.toStringAsFixed(1)})');
    }

    _logger.success('搜索完成: ${deduplicated.length} 个结果');
    return deduplicated;
  }
  
  /// 计算相关性评分
  double _calculateRelevanceScore(String title, String keyword) {
    final lowerTitle = title.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    double score = 0.0;
    
    // 1. 完全匹配 - 最高优先级
    if (lowerTitle == lowerKeyword) {
      return 1000.0; // 极高分数确保排第一
    }
    
    // 2. 标题开头匹配
    if (lowerTitle.startsWith(lowerKeyword)) {
      score += 80.0;
      
      // 检查是否是精确匹配后跟空格或标点（如 "命运石之门 第二季"）
      if (lowerTitle.length > lowerKeyword.length) {
        final nextChar = lowerTitle[lowerKeyword.length];
        if (nextChar == ' ' || nextChar == '　' || nextChar == '-' || 
            nextChar == '(' || nextChar == '（' || nextChar == ':' || 
            nextChar == '：' || nextChar == '第') {
          score += 20.0; // 自然分隔符，可能是续集
        }
      }
    }
    // 3. 标题包含完整关键词
    else if (lowerTitle.contains(lowerKeyword)) {
      score += 60.0;
    }
    
    // 4. 长度相似性（精确匹配长度的优先级更高）
    final lengthDiff = (lowerTitle.length - lowerKeyword.length).abs();
    if (lengthDiff == 0) {
      score += 50.0; // 长度完全相同
    } else if (lengthDiff <= 2) {
      score += 30.0; // 长度非常接近
    } else if (lengthDiff <= 5) {
      score += 10.0; // 长度接近
    } else if (lengthDiff > 15) {
      score *= 0.7; // 长度差异很大，降低评分
    }
    
    // 5. 续集和变体惩罚（关键逻辑）
    // 如果用户搜索的不包含续集标记，那么包含续集标记的结果应该被严重惩罚
    final keywordHasSequelMarker = _hasSequelMarker(lowerKeyword);
    final titleHasSequelMarker = _hasSequelMarker(lowerTitle);
    
    if (!keywordHasSequelMarker && titleHasSequelMarker) {
      // 用户搜索原作，但结果是续集 - 严重惩罚
      score *= 0.2; // 降低到原来的 20%
      _logger.debug('  续集惩罚: $title (${score.toStringAsFixed(1)})');
    }
    
    // 6. 特殊情况：标题末尾有数字或字母（如 "命运石之门0"）
    if (!lowerKeyword.contains(RegExp(r'[0-9]')) && 
        lowerTitle.contains(RegExp(r'[0-9]'))) {
      // 用户没搜索数字，但标题有数字 - 额外惩罚
      score *= 0.5;
    }
    
    return score;
  }
  
  /// 检查是否包含续集标记
  bool _hasSequelMarker(String text) {
    final sequelMarkers = [
      '0', '零', 'zero',
      '第二', '第三', '第四', '第五', '第2', '第3', '第4', '第5',
      'season 2', 'season 3', 'season 4', 's2', 's3', 's4',
      '2nd season', '3rd season', '4th season',
      'ii', 'iii', 'iv', 'v',
      '23β', '23b', '负荷', '线性', '既视感',
      '剧场版', 'movie', 'ova', 'sp', 'special',
      '新', '续', '再', '完结篇',
    ];
    
    for (final marker in sequelMarkers) {
      if (text.contains(marker)) {
        return true;
      }
    }
    
    return false;
  }

  /// 使用单个规则搜索
  Future<List<Anime>> _searchWithRule(
    String keyword,
    SourceRule rule,
  ) async {
    // 1. 获取 HTML
    final document = await _fetcher.fetchSearchPage(keyword, rule);

    // 2. 选择节点
    final nodes = _selector.selectNodes(document, rule.searchList);
    if (nodes.isEmpty) {
      _logger.warning('未找到匹配节点');
      return [];
    }

    // 3. 过滤节点
    final filteredNodes = _filter.filterAnimeCards(nodes);
    if (filteredNodes.isEmpty) {
      _logger.warning('所有节点被过滤');
      return [];
    }

    // 3.5. 展开容器节点（如果节点是容器，提取其中的卡片）
    final expandedNodes = _expandContainers(filteredNodes);
    _logger.info('展开后节点数: ${expandedNodes.length}');

    // 4. 提取动漫信息
    final animes = <Anime>[];
    for (int i = 0; i < expandedNodes.length; i++) {
      final node = expandedNodes[i];
      
      try {
        final anime = _extractAnimeFromNode(node, rule, i);
        if (anime != null) {
          animes.add(anime);
        }
      } catch (e) {
        _logger.error('提取节点 $i 失败: $e');
      }
    }

    return animes;
  }
  
  /// 展开容器节点，提取其中的卡片
  /// 完全基于结构特征，不依赖 class 名称
  List<dom.Element> _expandContainers(List<dom.Element> nodes) {
    final expanded = <dom.Element>[];
    
    for (final node in nodes) {
      if (_isContainer(node)) {
        // 这是一个容器，提取其中的卡片
        _logger.debug('展开容器: ${node.localName}');
        
        final cards = <dom.Element>[];
        
        // 策略0: 优先查找常见的卡片 class 名称
        final commonCardClasses = [
          'video-search-item', 'search-item', 'anime-item', 'card-item',
          'list-item', 'result-item', 'media-item', 'content-item',
        ];
        
        for (final className in commonCardClasses) {
          final found = node.querySelectorAll('.$className, [class*="$className"]');
          if (found.isNotEmpty) {
            _logger.debug('  -> 通过 class="$className" 找到 ${found.length} 个卡片');
            cards.addAll(found.where((card) => _isValidCard(card)));
            if (cards.isNotEmpty) break;
          }
        }
        
        // 策略1: 查找直接子元素中包含链接的
        if (cards.isEmpty) {
          for (final child in node.children) {
            if (child.querySelector('a[href]') != null && _isValidCard(child)) {
              cards.add(child);
            }
          }
        }
        
        // 策略2: 如果直接子元素不够，查找所有包含"链接+图片+标题"的元素
        if (cards.length < 3) {
          cards.clear();
          final allDivs = node.querySelectorAll('div');
          
          // 按完整度排序：优先选择同时有链接、图片和标题的
          final scored = <MapEntry<dom.Element, int>>[];
          
          for (final div in allDivs) {
            final hasLink = div.querySelector('a[href]') != null;
            final hasImage = div.querySelector('img') != null;
            final hasTitle = div.querySelector('h1, h2, h3, h4, h5, h6, .title') != null;
            
            // 必须有链接
            if (!hasLink) continue;
            
            // 计算完整度分数
            int score = 0;
            if (hasImage) score += 10;
            if (hasTitle) score += 10;
            
            // 文本长度合理加分
            final textLength = div.text.trim().length;
            if (textLength > 10 && textLength < 1000) score += 5;
            
            // 检查 class 名称，包含 "item" 的加分
            final className = div.attributes['class'] ?? '';
            if (className.contains('item') || className.contains('card')) {
              score += 15;
            }
            
            // 通过验证
            if (_isValidCard(div)) {
              scored.add(MapEntry(div, score));
            }
          }
          
          // 按分数排序
          scored.sort((a, b) => b.value.compareTo(a.value));
          
          // 选择高分的，避免父子重复
          for (final entry in scored) {
            final div = entry.key;
            if (!cards.any((existing) => existing.contains(div) || div.contains(existing))) {
              cards.add(div);
            }
          }
        }
        
        if (cards.isNotEmpty) {
          _logger.debug('  -> 从容器中提取 ${cards.length} 个卡片');
          // 调试：输出第一个卡片的结构
          if (cards.isNotEmpty) {
            final first = cards.first;
            _logger.debug('  -> 第一个卡片: ${first.localName}, class="${first.attributes["class"]}"');
            _logger.debug('  -> 包含链接: ${first.querySelectorAll("a").length}');
            _logger.debug('  -> 包含图片: ${first.querySelectorAll("img").length}');
            _logger.debug('  -> 包含标题: ${first.querySelectorAll("h1, h2, h3, h4, h5, h6, .title").length}');
          }
          expanded.addAll(cards);
        } else {
          // 如果提取失败，保留原节点
          _logger.warning('  -> 容器展开失败，保留原节点');
          expanded.add(node);
        }
      } else {
        // 不是容器，直接添加
        expanded.add(node);
      }
    }
    
    return expanded;
  }
  
  /// 验证是否为有效的卡片（过滤导航链接等）
  bool _isValidCard(dom.Element element) {
    final text = element.text.trim();
    
    // 1. 文本太短（可能是导航）
    if (text.length < 2) {
      return false;
    }
    
    // 2. 常见导航关键词
    final navigationKeywords = [
      '首页', '主页', 'home', '返回',
      '分类', '排行', '榜单', '推荐',
      '最新', '热门', '完结', '连载',
      '国产', '日本', '欧美', '其他',
      '泡面番', '剧场版', '特别篇',
      '登录', '注册', '搜索',
    ];
    
    final lowerText = text.toLowerCase();
    for (final keyword in navigationKeywords) {
      // 如果文本完全等于导航关键词（不是包含）
      if (lowerText == keyword.toLowerCase() || 
          lowerText == keyword) {
        return false;
      }
    }
    
    // 3. 包含网站描述性文字（通常很长且包含特定词）
    if (text.length > 50 && (
        text.contains('网站') || 
        text.contains('分享') || 
        text.contains('观看') ||
        text.contains('在线') ||
        text.contains('免费'))) {
      return false;
    }
    
    // 4. 必须有图片或明确的标题标签（排除纯文本链接）
    final hasImage = element.querySelector('img') != null;
    final hasTitle = element.querySelector('h1, h2, h3, h4, h5, h6, .title, [title]') != null;
    
    if (!hasImage && !hasTitle) {
      return false;
    }
    
    return true;
  }
  
  /// 判断是否为容器节点
  /// 完全基于结构特征，不依赖 class 名称
  bool _isContainer(dom.Element node) {
    // 统计有多少个子元素包含链接
    final childrenWithLinks = node.children.where((child) {
      return child.querySelector('a[href]') != null;
    }).toList();
    
    // 如果有 3 个以上带链接的直接子元素，很可能是容器
    if (childrenWithLinks.length >= 3) {
      return true;
    }
    
    // 进一步检查：如果子元素不多，但孙元素很多（嵌套结构）
    final grandchildrenWithLinks = node.querySelectorAll('a[href]').length;
    if (grandchildrenWithLinks >= 5) {
      // 有很多链接，但直接子元素不多，说明是深层嵌套的容器
      return true;
    }
    
    return false;
  }

  /// 从节点提取动漫信息
  Anime? _extractAnimeFromNode(
    dom.Element node,
    SourceRule rule,
    int index,
  ) {
    // 1. 提取标题
    final rawTitle = _extractor.extractTitle(node);
    if (rawTitle.isEmpty) {
      _logger.warning('标题为空');
      return null;
    }

    // 2. 清洗标题
    final cleanedTitle = _normalizer.clean(rawTitle);

    // 3. 验证标题
    if (!_validator.isValid(cleanedTitle)) {
      return null;
    }

    // 4. 提取链接
    final detailUrl = _extractDetailUrl(node, rule);
    if (detailUrl.isEmpty) {
      _logger.warning('链接为空');
      return null;
    }

    // 5. 提取图片
    final imageUrl = _extractImageUrl(node, rule);

    // 6. 创建 Anime 对象
    return Anime(
      id: '${rule.name}_${index}_${DateTime.now().millisecondsSinceEpoch}',
      title: cleanedTitle,
      description: '来源: ${rule.name}',
      imageUrl: imageUrl,
      detailUrl: detailUrl,  // 详情页URL
      videoUrl: '',          // 视频URL在详情页获取
      genres: [rule.name],
      rating: 0.0,
      year: DateTime.now().year,
      status: '未知',
      episodes: 0,
    );
  }

  /// 提取详情页链接
  String _extractDetailUrl(dom.Element node, SourceRule rule) {
    final links = node.querySelectorAll('a[href]');
    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      
      // 跳过空链接和纯 JavaScript
      if (href.isEmpty || href.startsWith('javascript:')) {
        continue;
      }
      
      // 跳过空锚点，但允许 SPA 路由（如 #/detail/123）
      if (href == '#') {
        continue;
      }
      
      // 有效链接
      return _makeAbsoluteUrl(href, rule.baseURL);
    }
    return '';
  }

  /// 提取图片链接
  String _extractImageUrl(dom.Element node, SourceRule rule) {
    final images = node.querySelectorAll('img');
    for (final img in images) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (src.isNotEmpty) {
        return _makeAbsoluteUrl(src, rule.baseURL);
      }
    }
    return '';
  }

  /// 转换为绝对 URL
  String _makeAbsoluteUrl(String url, String baseUrl) {
    if (url.startsWith('http')) return url;

    try {
      final base = Uri.parse(baseUrl);
      final resolved = base.resolve(url);
      return resolved.toString();
    } catch (e) {
      // 降级处理
      final cleanBase = baseUrl.replaceAll(RegExp(r'/$'), '');
      final cleanUrl = url.replaceAll(RegExp(r'^/'), '');
      return '$cleanBase/$cleanUrl';
    }
  }
}
