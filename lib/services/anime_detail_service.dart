import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/anime.dart';
import '../models/source_rule.dart';

class AnimeDetailService {
  static final AnimeDetailService _instance = AnimeDetailService._internal();
  factory AnimeDetailService() => _instance;
  AnimeDetailService._internal();

  /// 从详情页URL获取完整的动漫信息
  Future<Anime> fetchAnimeDetail(Anime basicAnime, SourceRule rule) async {
    try {
      print('开始获取动漫详情: ${basicAnime.title}');
      print('详情页URL: ${basicAnime.videoUrl}');
      
      // 发送HTTP请求获取详情页
      final response = await http.get(
        Uri.parse(basicAnime.videoUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        print('详情页请求失败: ${response.statusCode}');
        return basicAnime;
      }

      print('详情页响应长度: ${response.body.length}');
      
      // 解析HTML
      final document = html_parser.parse(response.body);
      
      // 提取简介
      String description = await _extractDescription(document, rule);
      
      // 提取集数列表
      List<Episode> episodes = await _extractEpisodes(document, rule);
      
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
  Future<List<Episode>> _extractEpisodes(dom.Document document, SourceRule rule) async {
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
      episodes = await _extractEpisodesWithSmartSelector(document, rule);
      
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
        final episodeLinks = _selectByXPath(chapterContainer, rule.chapterResult);
        print('找到集数链接: ${episodeLinks.length} 个');
        
        for (int i = 0; i < episodeLinks.length; i++) {
          final link = episodeLinks[i];
          String episodeTitle = link.text.trim();
          String episodeUrl = link.attributes['href'] ?? '';
          
          if (episodeUrl.isNotEmpty) {
            // 处理相对URL
            if (!episodeUrl.startsWith('http')) {
              episodeUrl = rule.baseURL.replaceAll(RegExp(r'/$'), '') + '/' + episodeUrl.replaceAll(RegExp(r'^/'), '');
            }
            
            episodes.add(Episode(
              id: '${rule.name}_ep_${i + 1}',
              title: episodeTitle.isNotEmpty ? episodeTitle : '第${i + 1}集',
              videoUrl: episodeUrl,
              episodeNumber: i + 1,
              thumbnail: '',
              duration: const Duration(minutes: 24),
            ));
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
  Future<List<Episode>> _extractEpisodesWithSmartSelector(dom.Document document, SourceRule rule) async {
    try {
      List<Episode> episodes = [];
      
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
                if (!episodeUrl.startsWith('http')) {
                  episodeUrl = rule.baseURL.replaceAll(RegExp(r'/$'), '') + '/' + episodeUrl.replaceAll(RegExp(r'^/'), '');
                }
                
                episodes.add(Episode(
                  id: '${rule.name}_ep_${i + 1}',
                  title: episodeTitle.isNotEmpty ? episodeTitle : '第${i + 1}集',
                  videoUrl: episodeUrl,
                  episodeNumber: i + 1,
                  thumbnail: '',
                  duration: const Duration(minutes: 24),
                ));
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
          
          // 更严格的集数链接判断
          if (_isValidEpisodeLink(episodeTitle, episodeUrl) && 
              (episodeUrl.contains('play') || episodeUrl.contains('episode') || episodeUrl.contains('watch'))) {
            
            if (!episodeUrl.startsWith('http')) {
              episodeUrl = rule.baseURL.replaceAll(RegExp(r'/$'), '') + '/' + episodeUrl.replaceAll(RegExp(r'^/'), '');
            }
            
            episodes.add(Episode(
              id: '${rule.name}_ep_${episodes.length + 1}',
              title: episodeTitle.isNotEmpty ? episodeTitle : '第${episodes.length + 1}集',
              videoUrl: episodeUrl,
              episodeNumber: episodes.length + 1,
              thumbnail: '',
              duration: const Duration(minutes: 24),
            ));
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
      'play', 'episode', 'watch', 'video', 'ep'
    ];
    
    bool hasValidUrlPattern = false;
    for (final pattern in validUrlPatterns) {
      if (url.toLowerCase().contains(pattern)) {
        hasValidUrlPattern = true;
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
    
    print('开始去重，原始集数: ${episodes.length}');
    
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
      
      print('检查集数: "${episode.title}" -> 集数: $episodeNum');
      
      // 多重去重条件
      bool isDuplicate = false;
      
      // 1. 检查集数编号重复
      if (episodeNum != null && seenEpisodeNumbers.contains(episodeNum)) {
        print('跳过重复集数编号: $episodeNum (${episode.title})');
        isDuplicate = true;
      }
      
      // 2. 检查标题重复
      if (seenTitles.contains(normalizedTitle)) {
        print('跳过重复标题: ${episode.title}');
        isDuplicate = true;
      }
      
      // 3. 检查URL重复
      final isDuplicateUrl = uniqueEpisodes.any((e) => e.videoUrl == episode.videoUrl);
      if (isDuplicateUrl) {
        print('跳过重复URL: ${episode.videoUrl}');
        isDuplicate = true;
      }
      
      if (!isDuplicate) {
        if (episodeNum != null) {
          seenEpisodeNumbers.add(episodeNum);
        }
        seenTitles.add(normalizedTitle);
        uniqueEpisodes.add(episode);
        print('保留集数: "${episode.title}"');
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
    
    print('去重完成，最终集数: ${finalEpisodes.length}');
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
  
  /// 简化的XPath选择器实现（复用搜索服务的逻辑）
  List<dom.Element> _selectByXPath(dom.Node context, String xpath) {
    try {
      print('详情页XPath选择器: $xpath');
      
      // 处理包含text()的XPath
      if (xpath.contains('/text()')) {
        final pathWithoutText = xpath.replaceAll('/text()', '');
        return _selectByXPath(context, pathWithoutText);
      }
      
      // 简单的CSS选择器转换
      String cssSelector = xpath;
      
      // 移除开头的 //
      if (cssSelector.startsWith('//')) {
        cssSelector = cssSelector.substring(2);
      }
      
      // 处理基本的XPath表达式
      cssSelector = cssSelector.replaceAllMapped(RegExp(r'(\w+)\[(\d+)\]'), (match) {
        final tag = match.group(1);
        final index = int.parse(match.group(2)!) - 1;
        return '$tag:nth-of-type(${index + 1})';
      });
      
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
}

