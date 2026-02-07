import 'package:html/dom.dart' as dom;
import '../models/anime.dart';
import '../models/source_rule.dart';
import 'search/html_fetcher_hybrid.dart';
import 'search/search_logger.dart';
import 'spa_episode_extractor.dart';

class AnimeDetailService {
  static final AnimeDetailService _instance = AnimeDetailService._internal();
  factory AnimeDetailService() => _instance;
  AnimeDetailService._internal();

  late final HtmlFetcherHybrid _fetcher = HtmlFetcherHybrid(
    logger: SearchLogger(enabled: true, verbose: false),
  );

  /// 提取路线列表
  Future<List<String>> extractRoads(String detailUrl, SourceRule rule) async {
    try {
      print('开始提取路线列表');
      print('详情页URL: $detailUrl');
      print('roadList XPath: ${rule.roadList}');
      print('roadName XPath: ${rule.roadName}');
      
      // 获取详情页 HTML
      final tempRule = SourceRule(
        id: rule.id,
        name: rule.name,
        version: rule.version,
        baseURL: rule.baseURL,
        searchURL: detailUrl,
        searchList: '',
        searchName: '',
        searchResult: '',
        imgRoads: '',
        chapterRoads: '',
        chapterResult: '',
        enableDynamicLoading: rule.enableDynamicLoading,
      );
      
      // 使用 fetchSearchPage 获取文档
      final document = await _fetcher.fetchSearchPage('', tempRule);
      
      // 使用 roadList XPath 定位路线容器
      var roadContainer = _selectByXPath(document, rule.roadList);
      print('使用 roadList XPath 找到 ${roadContainer.length} 个容器');
      
      // 如果找到的容器不包含 tab 元素，尝试在其子元素中查找
      if (roadContainer.isNotEmpty) {
        final hasTabsInContainer = roadContainer.first.querySelectorAll('.van-tab, [role="tab"]').isNotEmpty;
        if (!hasTabsInContainer) {
          print('⚠️ 容器内没有 tab 元素，尝试查找子容器');
          // 在找到的容器内查找包含 tabs 的子容器
          final subContainers = roadContainer.first.querySelectorAll('div');
          for (final sub in subContainers) {
            if (sub.querySelectorAll('.van-tab, [role="tab"]').isNotEmpty) {
              print('✓ 在子容器中找到 tab 元素');
              roadContainer = [sub];
              break;
            }
          }
        }
      }
      
      // 如果还是没找到，尝试全局查找 tabs 容器
      if (roadContainer.isEmpty || roadContainer.first.querySelectorAll('.van-tab, [role="tab"]').isEmpty) {
        print('⚠️ roadList XPath 未找到有效容器，尝试全局查找 tabs');
        final tabsContainers = document.querySelectorAll('.van-tabs, .van-tabs__nav, [class*="tabs"]');
        if (tabsContainers.isNotEmpty) {
          print('✓ 全局找到 ${tabsContainers.length} 个 tabs 容器');
          roadContainer = [tabsContainers.first];
        }
      }
      
      if (roadContainer.isEmpty) {
        print('❌ 未找到路线容器');
        return [];
      }
      
      // 打印容器的 HTML 内容（前 500 字符）
      final containerHtml = roadContainer.first.outerHtml;
      print('容器 HTML 预览 (${containerHtml.length} 字符):');
      print(containerHtml.substring(0, containerHtml.length > 500 ? 500 : containerHtml.length));
      
      final roads = <String>[];
      
      // 在容器内查找所有路线元素
      // 先尝试查找所有 tab 元素
      final tabElements = roadContainer.first.querySelectorAll('.van-tab, [role="tab"], .tab-item, .route-item');
      print('在容器内找到 ${tabElements.length} 个 tab 元素');
      
      if (tabElements.isNotEmpty) {
        // 从每个 tab 元素中提取名称
        for (var i = 0; i < tabElements.length; i++) {
          final element = tabElements[i];
          
          // 尝试多种方式提取名称
          String roadName = '';
          
          // 方式1: 查找 .van-tab__text 或 span
          final nameSpan = element.querySelector('.van-tab__text, .tab-text, span');
          if (nameSpan != null) {
            roadName = nameSpan.text.trim();
          }
          
          // 方式2: 直接使用元素文本
          if (roadName.isEmpty) {
            roadName = element.text.trim();
          }
          
          // 清理名称（移除徽章等）
          roadName = roadName.replaceAll(RegExp(r'[VIP]+'), '').trim();
          
          if (roadName.isEmpty) {
            roadName = '线路${i + 1}';
          }
          
          print('路线 $i: $roadName');
          roads.add(roadName);
        }
      } else {
        // 如果没找到 tab 元素，尝试查找子元素
        print('未找到 tab 元素，尝试查找所有子元素');
        
        // 直接查找容器的直接子元素
        final children = roadContainer.first.children;
        print('容器有 ${children.length} 个直接子元素');
        
        for (var i = 0; i < children.length; i++) {
          final child = children[i];
          print('子元素 $i: ${child.localName}, class="${child.className}", text="${child.text.trim()}"');
          
          // 提取文本
          String roadName = child.text.trim();
          
          // 清理名称
          roadName = roadName.replaceAll(RegExp(r'[VIP]+'), '').trim();
          
          if (roadName.isNotEmpty && roadName.length < 50) {
            print('  -> 添加路线: $roadName');
            roads.add(roadName);
          }
        }
        
        // 如果还是没找到，尝试查找所有 div
        if (roads.isEmpty) {
          print('尝试查找所有 div 元素');
          final allDivs = roadContainer.first.querySelectorAll('div');
          print('容器内共有 ${allDivs.length} 个 div');
          
          // 过滤出可能是路线的元素
          for (var i = 0; i < allDivs.length && roads.length < 10; i++) {
            final div = allDivs[i];
            final text = div.text.trim();
            
            // 检查是否是路线元素
            if (text.isNotEmpty && text.length < 20 && 
                (text.contains('线路') || text.contains('路线') || 
                 text.contains('B站') || text.contains('红牛') ||
                 RegExp(r'^[A-Z]+\d*$').hasMatch(text))) {
              print('可能的路线 $i: $text');
              roads.add(text);
            }
          }
        }
      }
      
      // 去重
      final uniqueRoads = roads.toSet().toList();
      print('去重后提取到 ${uniqueRoads.length} 个路线');
      
      return uniqueRoads;
    } catch (e) {
      print('提取路线列表失败: $e');
      return [];
    }
  }

  /// 使用指定路线获取动漫详情
  Future<Anime> fetchAnimeDetailWithRoad(
    Anime basicAnime,
    SourceRule rule, {
    int? roadIndex,
  }) async {
    try {
      print('开始获取动漫详情（路线索引: $roadIndex）');
      
      // 检查是否配置了路线
      final hasRoadConfig = rule.roadList.isNotEmpty && rule.roadName.isNotEmpty;
      
      // 如果配置了路线但没有提供路线索引，说明需要先选择路线
      if (hasRoadConfig && roadIndex == null) {
        print('⚠️ 检测到路线配置但未提供路线索引');
        print('   需要先在界面上选择路线');
        // 返回基础信息，不提取集数
        return basicAnime.copyWith(
          description: '请先选择播放路线',
          episodeList: [],
        );
      }
      
      // 如果指定了路线索引，需要先点击对应的路线
      // 这里我们通过修改 chapterRoads 来实现
      SourceRule effectiveRule = rule;
      
      if (roadIndex != null && rule.roadList.isNotEmpty) {
        print('使用路线索引 $roadIndex');
        // 修改 chapterRoads 为: roadList[roadIndex]/chapterRoads
        // 这样就会先定位到指定路线，再提取集数
        effectiveRule = rule.copyWith(
          chapterRoads: '(${rule.roadList})[${roadIndex + 1}]${rule.chapterRoads.isNotEmpty ? '/' + rule.chapterRoads.substring(2) : ''}',
        );
        print('修改后的 chapterRoads: ${effectiveRule.chapterRoads}');
      }
      
      // 调用原有的获取详情方法
      return await fetchAnimeDetail(basicAnime, effectiveRule);
    } catch (e) {
      print('获取动漫详情失败: $e');
      rethrow;
    }
  }

  /// 从详情页URL获取完整的动漫信息
  Future<Anime> fetchAnimeDetail(Anime basicAnime, SourceRule rule) async {
    try {
      // 使用detailUrl，如果为空则使用videoUrl作为后备
      final detailPageUrl = basicAnime.detailUrl.isNotEmpty 
          ? basicAnime.detailUrl 
          : basicAnime.videoUrl;
      
      if (detailPageUrl.isEmpty) {
        return basicAnime;
      }
      
      // 如果启用了动态加载，直接使用 SPA 提取器
      if (rule.enableDynamicLoading) {
        print('检测到动态加载配置，直接使用 SPA 提取器');
        try {
          final spaEpisodes = await SpaEpisodeExtractor.extractEpisodes(
            detailUrl: detailPageUrl,
            sourceName: rule.name,
          );
          
          if (spaEpisodes.isNotEmpty) {
            print('SPA 提取器成功提取 ${spaEpisodes.length} 集');
            return basicAnime.copyWith(
              episodes: spaEpisodes.length,
              episodeList: spaEpisodes,
            );
          }
        } catch (e) {
          print('SPA 提取器失败: $e，回退到常规提取');
        }
      }
      
      // 常规提取流程（静态页面或 SPA 提取失败时）
      final tempRule = SourceRule(
        id: rule.id,
        name: rule.name,
        version: rule.version,
        baseURL: rule.baseURL,
        searchURL: detailPageUrl,
        searchList: '',
        searchName: '',
        searchResult: '',
        imgRoads: rule.imgRoads,
        chapterRoads: rule.chapterRoads,
        chapterResult: rule.chapterResult,
        enableDynamicLoading: rule.enableDynamicLoading,
      );
      
      final document = await _fetcher.fetchSearchPage('', tempRule, forceDynamic: rule.enableDynamicLoading);
      
      // 提取简介
      String description = await _extractDescription(document, rule);
      
      // 提取集数列表
      List<Episode> episodes = await _extractEpisodes(document, rule, detailPageUrl);
      
      // 检查是否需要使用 SPA 提取器（作为回退方案）
      final needsSpaExtractor = episodes.isEmpty || 
                                episodes.any((e) => e.videoUrl.isEmpty);
      
      if (needsSpaExtractor && !rule.enableDynamicLoading) {
        print('检测到集数缺失或无 URL，尝试 SPA 提取器作为回退方案...');
        try {
          final spaEpisodes = await SpaEpisodeExtractor.extractEpisodes(
            detailUrl: detailPageUrl,
            sourceName: rule.name,
          );
          
          if (spaEpisodes.isNotEmpty) {
            print('SPA 提取器成功提取 ${spaEpisodes.length} 集');
            episodes = spaEpisodes;
          }
        } catch (e) {
          print('SPA 提取器失败: $e');
        }
      }
      
      // 提取其他信息（年份、状态等）
      Map<String, dynamic> additionalInfo = await _extractAdditionalInfo(document, rule);
      
      // 创建完整的动漫对象
      return basicAnime.copyWith(
        description: description.isNotEmpty ? description : basicAnime.description,
        episodes: episodes.length > 0 ? episodes.length : basicAnime.episodes,
        year: additionalInfo['year'] ?? basicAnime.year,
        status: additionalInfo['status'] ?? basicAnime.status,
        rating: additionalInfo['rating'] ?? basicAnime.rating,
        episodeList: episodes,
      );
      
    } catch (e) {
      print('获取动漫详情失败: $e');
      return basicAnime;
    }
  }

  /// 提取动漫简介
  Future<String> _extractDescription(dom.Document document, SourceRule rule) async {
    try {
      print('开始提取简介...');
      
      // 尝试多种可能的简介选择器
      final List<String> descriptionSelectors = [
        '.detail-content .desc, .detail-desc, .video-desc',
        '.content .desc, .anime-desc, .description',
        '.detail .intro, .detail .summary',
        '.plot, .synopsis, .story',
        '.video-info-content, .video-info-main',
      ];
      
      for (String selector in descriptionSelectors) {
        final elements = document.querySelectorAll(selector);
        for (var element in elements) {
          String text = element.text.trim();
          String cleanedText = _cleanDescriptionText(text);
          if (cleanedText.length > 20) {
            print('从选择器 $selector 找到简介: ${cleanedText.substring(0, cleanedText.length > 100 ? 100 : cleanedText.length)}...');
            return cleanedText;
          }
        }
      }
      
      // 尝试查找包含"简介"、"剧情"等关键词的相邻元素
      final keywordElements = document.querySelectorAll('*');
      for (var element in keywordElements) {
        String text = element.text.trim();
        if ((text == '简介' || text == '剧情' || text == '内容简介' || text == '故事简介') && 
            element.nextElementSibling != null) {
          String nextText = element.nextElementSibling!.text.trim();
          String cleanedText = _cleanDescriptionText(nextText);
          if (cleanedText.length > 20) {
            print('从关键词相邻元素找到简介: ${cleanedText.substring(0, cleanedText.length > 100 ? 100 : cleanedText.length)}...');
            return cleanedText;
          }
        }
      }
      
      // 查找段落文本，但更严格地过滤
      final paragraphs = document.querySelectorAll('p');
      List<String> candidateTexts = [];
      
      for (var p in paragraphs) {
        String text = p.text.trim();
        String cleanedText = _cleanDescriptionText(text);
        
        // 更严格的过滤条件
        if (cleanedText.length > 50 && cleanedText.length < 1000 && 
            _isValidDescription(cleanedText)) {
          candidateTexts.add(cleanedText);
        }
      }
      
      // 选择最合适的文本作为简介
      if (candidateTexts.isNotEmpty) {
        // 优先选择长度适中的文本
        candidateTexts.sort((a, b) {
          // 优先选择200-800字符长度的文本
          int scoreA = _getDescriptionScore(a);
          int scoreB = _getDescriptionScore(b);
          return scoreB.compareTo(scoreA);
        });
        
        String description = candidateTexts.first;
        print('从段落提取简介: ${description.substring(0, description.length > 100 ? 100 : description.length)}...');
        return description;
      }
      
      print('未找到合适的简介');
      return '';
    } catch (e) {
      print('提取简介失败: $e');
      return '';
    }
  }

  /// 清理简介文本，移除不相关信息
  String _cleanDescriptionText(String text) {
    // 移除常见的非简介信息
    List<String> removePatterns = [
      r'导演[：:].+',
      r'声优[：:].+',
      r'主演[：:].+',
      r'类型[：:].+',
      r'地区[：:].+',
      r'年份[：:].+',
      r'语言[：:].+',
      r'上映时间[：:].+',
      r'更新时间[：:].+',
      r'播放[：:].+',
      r'下载[：:].+',
      r'收藏[：:].+',
      r'评分[：:].+',
      r'点击[：:].+',
      r'观看[：:].+',
      r'全集[：:].+',
      r'高清[：:].+',
      r'免费[：:].+',
      r'在线[：:].+',
      r'第\d+集',
      r'共\d+集',
      r'\d+P',
      r'BD',
      r'HD',
      r'蓝光',
    ];
    
    String cleaned = text;
    for (String pattern in removePatterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern), '');
    }
    
    // 移除多余的空白字符
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  /// 判断文本是否是有效的简介
  bool _isValidDescription(String text) {
    // 过滤掉明显不是简介的内容
    List<String> invalidKeywords = [
      '播放', '下载', '更新', '收藏', '点击', '观看',
      '全集', '高清', '免费', '在线', '蓝光', 'BD', 'HD',
      '导演', '声优', '主演', '类型', '地区', '年份', '语言',
      '上映时间', '更新时间', '评分'
    ];
    
    for (String keyword in invalidKeywords) {
      if (text.contains(keyword)) {
        return false;
      }
    }
    
    // 检查是否包含故事性词汇
    List<String> storyKeywords = [
      '故事', '讲述', '描述', '主人公', '角色', '世界', '冒险',
      '学校', '生活', '友情', '爱情', '战斗', '魔法', '科幻',
      '未来', '过去', '梦想', '成长', '挑战'
    ];
    
    for (String keyword in storyKeywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    
    // 如果没有明显的故事关键词，但文本较长且结构合理，也可能是简介
    return text.length > 100 && text.contains('。');
  }

  /// 计算简介文本的评分
  int _getDescriptionScore(String text) {
    int score = 0;
    
    // 长度评分（200-800字符最佳）
    if (text.length >= 200 && text.length <= 800) {
      score += 100;
    } else if (text.length >= 100 && text.length <= 1200) {
      score += 50;
    }
    
    // 包含故事关键词加分
    List<String> storyKeywords = [
      '故事', '讲述', '描述', '主人公', '角色', '世界', '冒险'
    ];
    
    for (String keyword in storyKeywords) {
      if (text.contains(keyword)) {
        score += 20;
      }
    }
    
    // 包含句号表示结构完整
    score += text.split('。').length * 5;
    
    return score;
  }

  /// 提取集数列表
  Future<List<Episode>> _extractEpisodes(dom.Document document, SourceRule rule, String detailUrl) async {
    try {
      List<Episode> episodes = [];
      
      print('开始提取集数，规则: ${rule.name}');
      print('章节路径: ${rule.chapterRoads}');
      print('章节结果: ${rule.chapterResult}');
      
      // 首先尝试使用规则中的章节选择器
      if (rule.chapterRoads.isNotEmpty) {
        episodes = await _extractEpisodesWithRule(document, rule);
        if (episodes.isNotEmpty) {
          print('使用规则提取到 ${episodes.length} 集');
          return episodes;
        }
      }
      
      // 如果规则失败，使用智能集数提取器
      print('规则提取失败，启用智能集数提取器...');
      episodes = await _extractEpisodesWithSmartSelector(document, rule, detailUrl);
      
      return episodes;
    } catch (e) {
      print('集数提取失败: $e');
      return [];
    }
  }
  
  /// 使用规则提取集数
  Future<List<Episode>> _extractEpisodesWithRule(dom.Document document, SourceRule rule) async {
    try {
      List<Episode> episodes = [];
      
      // 使用规则中的章节选择器
      final chapterElements = _selectByXPath(document, rule.chapterRoads);
      print('找到章节容器: ${chapterElements.length} 个');
      
      if (chapterElements.isNotEmpty) {
        final chapterContainer = chapterElements.first;
        
        // 尝试1: 使用规则中的章节结果选择器
        var episodeElements = _selectByXPath(chapterContainer, rule.chapterResult);
        print('找到集数元素（规则）: ${episodeElements.length} 个');
        
        // 尝试2: 如果规则失败，查找所有可能的集数元素
        if (episodeElements.isEmpty) {
          print('规则选择器失败，尝试通用选择器...');
          print('容器 HTML 预览: ${chapterContainer.outerHtml.substring(0, chapterContainer.outerHtml.length > 500 ? 500 : chapterContainer.outerHtml.length)}');
          
          // 先在容器内查找
          episodeElements = chapterContainer.querySelectorAll(
            '.van-grid-item, .episode-item, .chapter-item, '
            '[class*="episode"], [class*="chapter"], [class*="grid-item"]'
          );
          print('在容器内找到: ${episodeElements.length} 个');
          
          // 如果容器内没找到，尝试在整个文档中查找
          if (episodeElements.isEmpty) {
            print('容器内未找到，尝试全局查找...');
            episodeElements = document.querySelectorAll(
              '.van-grid-item__text, .episode-item, .chapter-item, '
              '[class*="episode"], [class*="chapter"]'
            );
            print('全局找到: ${episodeElements.length} 个');
            
            // 如果还是没找到，尝试更宽泛的选择器
            if (episodeElements.isEmpty) {
              episodeElements = document.querySelectorAll('.van-grid-item');
              print('使用 .van-grid-item 找到: ${episodeElements.length} 个');
            }
          }
        }
        
        // 过滤和去重
        final seenTitles = <String>{};
        final navigationKeywords = {'首页', '目录', '推荐', '更新', '排行榜', '分类', '搜索', '我的'};
        
        for (int i = 0; i < episodeElements.length; i++) {
          final element = episodeElements[i];
          
          // 提取标题
          String episodeTitle = '';
          
          // 尝试从 span.van-grid-item__text 提取
          final titleSpan = element.querySelector('.van-grid-item__text, .episode-title, .chapter-title, span');
          if (titleSpan != null) {
            episodeTitle = titleSpan.text.trim();
          }
          
          // 如果没找到，使用元素自身的文本
          if (episodeTitle.isEmpty) {
            episodeTitle = element.text.trim();
          }
          
          // 过滤条件
          if (episodeTitle.isEmpty) continue;
          if (navigationKeywords.contains(episodeTitle)) continue; // 过滤导航
          if (seenTitles.contains(episodeTitle)) continue; // 去重
          
          // 检查是否是集数标题（包含"第X话"、"第X集"等）
          final isEpisode = RegExp(r'第\d+[话集]|EP?\d+|Episode\s*\d+', caseSensitive: false).hasMatch(episodeTitle);
          if (!isEpisode) {
            // 如果不是明显的集数标题，跳过（避免添加推荐的其他动漫）
            continue;
          }
          
          seenTitles.add(episodeTitle);
          
          print('集数 ${episodes.length + 1}: "$episodeTitle"');
          
          // 提取URL
          String episodeUrl = '';
          
          // 尝试1: 如果元素本身是 <a> 标签
          if (element.localName == 'a') {
            episodeUrl = element.attributes['href'] ?? '';
            if (episodeUrl.isNotEmpty) {
              print('  -> 元素本身是 <a>: $episodeUrl');
            } else {
              print('  -> <a> 标签但 href 为空');
              print('  -> 属性: ${element.attributes}');
            }
          }
          
          // 尝试2: 查找子元素中的 <a> 标签
          if (episodeUrl.isEmpty) {
            final link = element.querySelector('a[href]');
            if (link != null) {
              episodeUrl = link.attributes['href'] ?? '';
              print('  -> 从子 <a> 标签获取: $episodeUrl');
            }
          }
          
          // 尝试3: 查找 data-* 属性
          if (episodeUrl.isEmpty) {
            episodeUrl = element.attributes['data-url'] ?? 
                        element.attributes['data-href'] ?? 
                        element.attributes['data-link'] ?? 
                        element.attributes['data-episode'] ?? 
                        element.attributes['data-src'] ?? '';
            if (episodeUrl.isNotEmpty) {
              print('  -> 从 data-* 属性获取: $episodeUrl');
            }
          }
          
          // 尝试3: 对于 SPA，使用详情页 URL + 集数索引
          if (episodeUrl.isEmpty) {
            // 从详情页 URL 构造播放 URL
            // 例如: #/detail/20250119 -> #/play/20250119/1
            final detailUrl = rule.baseURL;
            if (detailUrl.contains('#/detail/')) {
              final id = detailUrl.split('#/detail/').last.split('?').first;
              episodeUrl = '${rule.baseURL}#/play/$id/${i + 1}';
              print('  -> 构造 SPA URL: $episodeUrl');
            }
          }
          
          // 验证和处理 URL
          if (episodeUrl.isNotEmpty) {
            // 过滤无效 URL
            if (episodeUrl.startsWith('javascript:') || episodeUrl == 'void(0)') {
              print('  -> 过滤无效 URL');
              continue;
            }
            
            // 处理相对 URL
            if (!episodeUrl.startsWith('http') && !episodeUrl.startsWith('#')) {
              episodeUrl = _makeAbsoluteUrl(episodeUrl, rule.baseURL);
            }
            
            episodes.add(Episode(
              id: '${rule.name}_ep_${episodes.length + 1}',
              title: episodeTitle.isNotEmpty ? episodeTitle : '第${episodes.length + 1}集',
              videoUrl: episodeUrl,
              episodeNumber: episodes.length + 1,
              thumbnail: '',
              duration: const Duration(minutes: 24),
            ));
            
            print('  ✓ 添加: $episodeTitle -> $episodeUrl');
          } else if (episodeTitle.isNotEmpty) {
            // 即使没有 URL，也添加集数（后续可以通过其他方式获取）
            episodes.add(Episode(
              id: '${rule.name}_ep_${episodes.length + 1}',
              title: episodeTitle,
              videoUrl: '', // 空 URL，需要后续处理
              episodeNumber: episodes.length + 1,
              thumbnail: '',
              duration: const Duration(minutes: 24),
            ));
            print('  ⚠ 添加（无URL）: $episodeTitle');
          }
        }
      }
      
      return episodes;
    } catch (e) {
      print('规则集数提取失败: $e');
      return [];
    }
  }
  
  /// 智能集数提取器
  Future<List<Episode>> _extractEpisodesWithSmartSelector(dom.Document document, SourceRule rule, String detailUrl) async {
    try {
      List<Episode> episodes = [];
      
      // 从详情页URL提取baseURL（更准确）
      String baseUrlForEpisodes = rule.baseURL;
      try {
        final detailUri = Uri.parse(detailUrl);
        baseUrlForEpisodes = '${detailUri.scheme}://${detailUri.host}';
        print('从详情页URL提取baseURL: $baseUrlForEpisodes');
      } catch (e) {
        print('无法从详情页URL提取baseURL，使用规则baseURL: ${rule.baseURL}');
      }
      
      // 策略1：查找常见的集数容器
      final episodeSelectors = [
        '.episode-list a',
        '.play-list a', 
        '.chapter-list a',
        '.playlist a',
        'a[href*="play"]',
        'a[href*="episode"]',
        'a[href*="watch"]',
        '.episode-link',
        '.play-link',
        '.chapter-link',
      ];
      
      for (final selector in episodeSelectors) {
        try {
          final links = document.querySelectorAll(selector);
          print('选择器 "$selector" 找到 ${links.length} 个链接');
          
          if (links.isNotEmpty) {
            for (int i = 0; i < links.length && i < 100; i++) {
              final link = links[i];
              String episodeTitle = link.text.trim();
              String episodeUrl = link.attributes['href'] ?? '';
              
              // 过滤掉明显不是集数的链接
              if (_isValidEpisodeLink(episodeTitle, episodeUrl)) {
                // 使用智能URL拼接（使用详情页的baseURL）
                if (!episodeUrl.startsWith('http')) {
                  episodeUrl = _makeAbsoluteUrl(episodeUrl, baseUrlForEpisodes);
                  print('智能选择器拼接URL: "$episodeUrl"');
                }
                
                episodes.add(Episode(
                  id: '${rule.name}_ep_${i + 1}',
                  title: episodeTitle.isNotEmpty ? episodeTitle : '第${i + 1}集',
                  videoUrl: episodeUrl,
                  episodeNumber: i + 1,
                  thumbnail: '',
                  duration: const Duration(minutes: 24),
                ));
                
                print('✓ 智能选择器添加集数: $episodeTitle -> $episodeUrl');
              }
            }
            
            if (episodes.isNotEmpty) {
              print('智能选择器 "$selector" 提取到 ${episodes.length} 集');
              break;
            }
          }
        } catch (e) {
          print('选择器 "$selector" 执行失败: $e');
        }
      }
      
      // 策略2：如果还没找到，尝试更通用的方法
      if (episodes.isEmpty) {
        print('尝试通用链接提取...');
        final allLinks = document.querySelectorAll('a[href]');
        print('文档中总共有 ${allLinks.length} 个链接');
        
        for (int i = 0; i < allLinks.length && episodes.length < 50; i++) {
          final link = allLinks[i];
          String episodeTitle = link.text.trim();
          String episodeUrl = link.attributes['href'] ?? '';
          
          // 更严格的集数链接判断（支持 /p/、/v/、/e/ 等缩写路径）
          if (_isValidEpisodeLink(episodeTitle, episodeUrl) && 
              (episodeUrl.contains('play') || episodeUrl.contains('episode') || episodeUrl.contains('watch') ||
               episodeUrl.contains('/p/') || episodeUrl.contains('/v/') || episodeUrl.contains('/e/'))) {
            
            // 使用智能URL拼接（使用详情页的baseURL）
            if (!episodeUrl.startsWith('http')) {
              episodeUrl = _makeAbsoluteUrl(episodeUrl, baseUrlForEpisodes);
              print('降级选择器拼接URL: "$episodeUrl"');
            }
            
            episodes.add(Episode(
              id: '${rule.name}_ep_${episodes.length + 1}',
              title: episodeTitle.isNotEmpty ? episodeTitle : '第${episodes.length + 1}集',
              videoUrl: episodeUrl,
              episodeNumber: episodes.length + 1,
              thumbnail: '',
              duration: const Duration(minutes: 24),
            ));
            
            print('✓ 降级选择器添加集数: $episodeTitle -> $episodeUrl');
          }
        }
      }
      
      // 去重和排序
      episodes = _deduplicateAndSortEpisodes(episodes);
      
      print('智能集数提取完成，去重后共找到 ${episodes.length} 集');
      return episodes;
    } catch (e) {
      print('智能集数提取失败: $e');
      return [];
    }
  }
  
  /// 判断是否为有效的集数链接
  bool _isValidEpisodeLink(String title, String url) {
    if (title.isEmpty || url.isEmpty) return false;
    
    print('检查集数链接: "$title" -> "$url"');
    
    // 排除明显不是集数的链接
    final invalidKeywords = [
      '首页', '主页', '搜索', '分类', '排行', '最新', '热门',
      '登录', '注册', '关于', '联系', '帮助', '反馈',
      '下载', '客户端', 'APP', '广告', '赞助',
      '线路', '播放线路', '第一线路', '第二线路', '第三线路',
      '高清', '超清', '蓝光', 'HD', 'BD', '1080P', '720P',
      '国语', '日语', '中字', '字幕', '配音',
      '预告', '花絮', '特典', '番外', '剧场版',
      '更换', '切换', '选择', '播放器',
    ];
    
    for (final keyword in invalidKeywords) {
      if (title.contains(keyword)) {
        print('过滤掉无效链接: "$title" (包含关键词: $keyword)');
        return false;
      }
    }
    
    // 检查URL是否包含播放相关的路径
    final validUrlPatterns = [
      'play', 'episode', 'watch', 'video', 'ep',
      '/p/',  // 支持 /p/ 路径（play的缩写）
      '/v/',  // 支持 /v/ 路径（video的缩写）
      '/e/',  // 支持 /e/ 路径（episode的缩写）
    ];
    
    bool hasValidUrlPattern = false;
    for (final pattern in validUrlPatterns) {
      if (url.toLowerCase().contains(pattern)) {
        hasValidUrlPattern = true;
        print('✓ URL包含有效路径标识: "$pattern"');
        break;
      }
    }
    
    if (!hasValidUrlPattern) {
      print('过滤掉无效URL: "$url" (不包含播放路径)');
      return false;
    }
    
    // 检查是否包含集数相关的关键词
    final episodeKeywords = [
      '第', '集', 'EP', 'ep', '话', '回', '章',
    ];
    
    bool hasEpisodeKeyword = false;
    for (final keyword in episodeKeywords) {
      if (title.contains(keyword)) {
        hasEpisodeKeyword = true;
        break;
      }
    }
    
    // 检查是否为纯数字格式的集数（如 "01", "02", "1", "2"）
    if (!hasEpisodeKeyword) {
      // 匹配纯数字或带前导零的数字
      if (RegExp(r'^\d{1,3}$').hasMatch(title.trim())) {
        final num = int.tryParse(title.trim());
        if (num != null && num >= 1 && num <= 999) {
          hasEpisodeKeyword = true;
          print('识别为数字集数: "$title"');
        }
      }
    }
    
    // 检查是否为标准集数格式（如 "第1集", "第01话"）
    if (!hasEpisodeKeyword) {
      if (RegExp(r'第\d+[集话回章]').hasMatch(title)) {
        hasEpisodeKeyword = true;
        print('识别为标准集数格式: "$title"');
      }
    }
    
    if (hasEpisodeKeyword) {
      print('有效集数链接: "$title"');
      return true;
    } else {
      print('过滤掉非集数链接: "$title" (无集数关键词)');
      return false;
    }
  }
  
  /// 去重和排序集数列表
  List<Episode> _deduplicateAndSortEpisodes(List<Episode> episodes) {
    if (episodes.isEmpty) return episodes;
    
    final originalCount = episodes.length;
    
    // 使用Set来存储已见过的集数编号，避免重复
    final Set<int> seenEpisodeNumbers = {};
    final Set<String> seenTitles = {};
    final List<Episode> uniqueEpisodes = [];
    
    // 首先按标题中的集数排序
    episodes.sort((a, b) {
      final numA = _extractEpisodeNumber(a.title);
      final numB = _extractEpisodeNumber(b.title);
      
      if (numA != null && numB != null) {
        return numA.compareTo(numB);
      } else if (numA != null) {
        return -1;
      } else if (numB != null) {
        return 1;
      } else {
        return a.title.compareTo(b.title);
      }
    });
    
    for (final episode in episodes) {
      final episodeNum = _extractEpisodeNumber(episode.title);
      final normalizedTitle = episode.title.toLowerCase().trim();
      
      // 多重去重条件
      bool isDuplicate = false;
      
      // 1. 检查集数编号重复
      if (episodeNum != null && seenEpisodeNumbers.contains(episodeNum)) {
        isDuplicate = true;
      }
      
      // 2. 检查标题重复
      if (seenTitles.contains(normalizedTitle)) {
        isDuplicate = true;
      }
      
      // 3. 检查URL重复
      final isDuplicateUrl = uniqueEpisodes.any((e) => e.videoUrl == episode.videoUrl);
      if (isDuplicateUrl) {
        isDuplicate = true;
      }
      
      if (!isDuplicate) {
        if (episodeNum != null) {
          seenEpisodeNumbers.add(episodeNum);
        }
        seenTitles.add(normalizedTitle);
        uniqueEpisodes.add(episode);
      }
    }
    
    // 重新设置集数编号，确保连续
    final List<Episode> finalEpisodes = [];
    for (int i = 0; i < uniqueEpisodes.length; i++) {
      finalEpisodes.add(Episode(
        id: '${uniqueEpisodes[i].id}_${i + 1}',
        title: uniqueEpisodes[i].title,
        videoUrl: uniqueEpisodes[i].videoUrl,
        episodeNumber: i + 1,
        thumbnail: uniqueEpisodes[i].thumbnail,
        duration: uniqueEpisodes[i].duration,
      ));
    }
    
    final duplicateCount = originalCount - uniqueEpisodes.length;
    if (duplicateCount > 0) {
      print('集数去重: ${originalCount} -> ${uniqueEpisodes.length} (过滤 ${duplicateCount} 个重复)');
    } else {
      print('集数处理: ${uniqueEpisodes.length} 集');
    }
    
    return finalEpisodes;
  }
  
  /// 从标题中提取集数
  int? _extractEpisodeNumber(String title) {
    // 匹配各种集数格式
    final patterns = [
      RegExp(r'第(\d+)[集话回章]'), // 第1集、第01话
      RegExp(r'EP(\d+)', caseSensitive: false), // EP01、ep1
      RegExp(r'^(\d+)$'), // 纯数字
      RegExp(r'(\d+)'), // 包含数字的任何格式
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final num = int.tryParse(numStr);
          if (num != null && num > 0 && num <= 999) {
            return num;
          }
        }
      }
    }
    
    return null;
  }
  
  /// 简化的XPath选择器实现
  List<dom.Element> _selectByXPath(dom.Node context, String xpath) {
    try {
      print('详情页XPath选择器: $xpath');
      
      // 处理包含text()的XPath
      if (xpath.contains('/text()')) {
        final pathWithoutText = xpath.replaceAll('/text()', '');
        return _selectByXPath(context, pathWithoutText);
      }
      
      // 处理属性选择器 //*[@id="value"] 或 //tag[@attr="value"]
      if (xpath.contains('[@')) {
        return _selectByXPathWithAttribute(context, xpath);
      }
      
      // 简单的CSS选择器转换
      String cssSelector = xpath;
      
      // 移除开头的 //
      if (cssSelector.startsWith('//')) {
        cssSelector = cssSelector.substring(2);
      }
      
      // 处理基本的XPath表达式 - 但不使用 :nth-of-type（不支持）
      // 改为手动过滤索引
      final indexPattern = RegExp(r'(\w+)\[(\d+)\]');
      final hasIndex = indexPattern.hasMatch(cssSelector);
      
      if (hasIndex) {
        // 提取索引信息
        final matches = indexPattern.allMatches(cssSelector);
        final indices = <int>[];
        
        // 移除索引，只保留标签
        cssSelector = cssSelector.replaceAllMapped(indexPattern, (match) {
          indices.add(int.parse(match.group(2)!));
          return match.group(1)!;
        });
        
        // 将 / 替换为 >
        cssSelector = cssSelector.replaceAll('/', ' > ');
        
        print('转换后的CSS选择器: $cssSelector (索引: $indices)');
        
        // 先用 CSS 选择器获取所有匹配的元素
        List<dom.Element> results = [];
        if (context is dom.Document) {
          results = context.querySelectorAll(cssSelector);
        } else if (context is dom.Element) {
          results = context.querySelectorAll(cssSelector);
        }
        
        // 如果有索引，只返回指定索引的元素
        if (indices.isNotEmpty && results.isNotEmpty) {
          final lastIndex = indices.last;
          if (lastIndex > 0 && lastIndex <= results.length) {
            results = [results[lastIndex - 1]]; // XPath 索引从 1 开始
          }
        }
        
        print('XPath选择器找到 ${results.length} 个元素');
        return results;
      }
      
      // 将 / 替换为 >
      cssSelector = cssSelector.replaceAll('/', ' > ');
      
      print('转换后的CSS选择器: $cssSelector');
      
      List<dom.Element> results = [];
      if (context is dom.Document) {
        results = context.querySelectorAll(cssSelector);
      } else if (context is dom.Element) {
        results = context.querySelectorAll(cssSelector);
      }
      
      print('XPath选择器找到 ${results.length} 个元素');
      return results;
    } catch (e) {
      print('XPath选择器执行失败: $xpath, 错误: $e');
      return [];
    }
  }
  
  /// 处理带属性选择器的 XPath
  /// 例如: //*[@id="线路一"], //div[@class="item"], //a[@href]
  List<dom.Element> _selectByXPathWithAttribute(dom.Node context, String xpath) {
    print('处理属性选择器 XPath: $xpath');
    
    try {
      // 先处理属性选择器部分，然后处理后续路径
      // 例如: //*[@id="page-detail"]/section/div[2]/div[1]
      
      // 分离属性选择器和后续路径
      final parts = xpath.split(']');
      if (parts.length < 2) {
        // 没有后续路径，使用原有逻辑
        return _selectByXPathWithAttributeSimple(context, xpath);
      }
      
      // 第一部分是属性选择器
      final attrPart = parts[0] + ']';
      // 剩余部分是后续路径
      final remainingPath = parts.sublist(1).join(']');
      
      print('属性选择器部分: $attrPart');
      print('后续路径: $remainingPath');
      
      // 先用属性选择器找到元素
      final elements = _selectByXPathWithAttributeSimple(context, attrPart);
      
      if (elements.isEmpty || remainingPath.isEmpty) {
        return elements;
      }
      
      // 对找到的每个元素，继续处理后续路径
      final results = <dom.Element>[];
      for (final element in elements) {
        final subResults = _selectByXPath(element, remainingPath);
        results.addAll(subResults);
      }
      
      print('属性选择器 + 路径匹配: ${results.length} 个节点');
      return results;
    } catch (e) {
      print('属性选择器执行失败: $xpath, 错误: $e');
      return [];
    }
  }
  
  /// 处理简单的属性选择器（不含后续路径）
  List<dom.Element> _selectByXPathWithAttributeSimple(dom.Node context, String xpath) {
    try {
      // 解析 XPath: //*[@id="value"] 或 //tag[@attr="value"]
      final match = RegExp(r'^//(\*|\w+)\[@(\w+)(?:="([^"]*)")?\]').firstMatch(xpath);
      
      if (match == null) {
        print('无法解析属性选择器: $xpath');
        return [];
      }
      
      final tag = match.group(1)!; // * 或具体标签名
      final attr = match.group(2)!; // 属性名
      final value = match.group(3); // 属性值（可能为空）
      
      print('解析结果: tag=$tag, attr=$attr, value=$value');
      
      // 转换为 CSS 选择器
      String cssSelector;
      
      // 特殊处理 class 属性：使用包含匹配而不是精确匹配
      if (attr == 'class' && value != null && value.contains(' ')) {
        // class 包含多个值，使用第一个 class 进行匹配
        final firstClass = value.split(' ').first;
        if (tag == '*') {
          cssSelector = '.$firstClass';
        } else {
          cssSelector = '$tag.$firstClass';
        }
        print('class 属性使用第一个值匹配: $cssSelector');
      } else if (tag == '*') {
        // 任意标签
        if (value != null) {
          cssSelector = '[$attr="$value"]';
        } else {
          cssSelector = '[$attr]';
        }
      } else {
        // 具体标签
        if (value != null) {
          cssSelector = '$tag[$attr="$value"]';
        } else {
          cssSelector = '$tag[$attr]';
        }
      }
      
      print('转换为 CSS: $cssSelector');
      
      List<dom.Element> results = [];
      if (context is dom.Document) {
        results = context.querySelectorAll(cssSelector);
      } else if (context is dom.Element) {
        results = context.querySelectorAll(cssSelector);
      }
      
      // 如果是 class 属性且有多个值，需要进一步过滤
      if (attr == 'class' && value != null && value.contains(' ') && results.isNotEmpty) {
        final classes = value.split(' ').where((c) => c.isNotEmpty).toSet();
        results = results.where((element) {
          final elementClasses = element.className.split(' ').where((c) => c.isNotEmpty).toSet();
          // 检查是否包含所有指定的 class
          return classes.every((c) => elementClasses.contains(c));
        }).toList();
        print('class 过滤后匹配: ${results.length} 个节点');
      }
      
      print('属性选择器匹配: ${results.length} 个节点');
      return results;
    } catch (e) {
      print('属性选择器执行失败: $xpath, 错误: $e');
      return [];
    }
  }

  /// 提取其他信息（年份、状态、评分等）
  Future<Map<String, dynamic>> _extractAdditionalInfo(dom.Document document, SourceRule rule) async {
    Map<String, dynamic> info = {};
    
    try {
      // 提取年份
      final yearElements = document.querySelectorAll('.year, .date, .time');
      for (var element in yearElements) {
        String text = element.text.trim();
        RegExp yearRegex = RegExp(r'(\d{4})');
        Match? match = yearRegex.firstMatch(text);
        if (match != null) {
          info['year'] = int.parse(match.group(1)!);
          break;
        }
      }
      
      // 提取状态
      final statusElements = document.querySelectorAll('.status, .state, .video-time');
      for (var element in statusElements) {
        String text = element.text.trim();
        if (text.contains('完结') || text.contains('已完结')) {
          info['status'] = '已完结';
          break;
        } else if (text.contains('更新') || text.contains('连载')) {
          info['status'] = '连载中';
          break;
        }
      }
      
      // 提取评分
      final ratingElements = document.querySelectorAll('.rating, .score, .star');
      for (var element in ratingElements) {
        String text = element.text.trim();
        RegExp ratingRegex = RegExp(r'(\d+\.?\d*)');
        Match? match = ratingRegex.firstMatch(text);
        if (match != null) {
          double rating = double.tryParse(match.group(1)!) ?? 0.0;
          if (rating > 0 && rating <= 10) {
            info['rating'] = rating;
            break;
          }
        }
      }
      
    } catch (e) {
      print('提取附加信息失败: $e');
    }
    
    return info;
  }
  
  /// 将相对URL转换为绝对URL
  /// 智能处理各种URL格式，包括baseURL包含路径的情况
  String _makeAbsoluteUrl(String url, String baseUrl) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    
    try {
      final base = Uri.parse(baseUrl);
      final resolved = base.resolve(url);
      return resolved.toString();
    } catch (e) {
      print('URL解析失败: $e');
      // 降级处理：简单拼接
      final cleanBase = baseUrl.replaceAll(RegExp(r'/$'), '');
      final cleanUrl = url.replaceAll(RegExp(r'^/'), '');
      return '$cleanBase/$cleanUrl';
    }
  }
}

