import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';

/// Bangumi API服务
class BangumiApiService {
  static const String _baseUrl = 'https://api.bgm.tv';
  static const String _userAgent = 'AnimeHUBX/1.0.0 (https://github.com/user/animehubx)';
  
  /// 获取当季热门动画
  Future<List<Anime>> getSeasonalAnime({int limit = 20}) async {
    try {
      // 获取当前年份和季度
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;
      String season;
      
      if (month >= 1 && month <= 3) {
        season = 'winter';
      } else if (month >= 4 && month <= 6) {
        season = 'spring';
      } else if (month >= 7 && month <= 9) {
        season = 'summer';
      } else {
        season = 'autumn';
      }
      
      print('BangumiAPI: 获取 $year年$season季 动画');
      
      // 使用calendar API获取当季动画
      final url = '$_baseUrl/calendar';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> weeklyData = json.decode(response.body);
        final List<Anime> animeList = [];
        
        // 遍历一周的数据
        for (final dayData in weeklyData) {
          if (dayData['items'] != null) {
            for (final item in dayData['items']) {
              if (item['type'] == 2) { // type 2 表示动画
                final anime = _parseAnimeFromBangumi(item);
                if (anime != null && animeList.length < limit) {
                  animeList.add(anime);
                }
              }
            }
          }
        }
        
        print('BangumiAPI: 成功获取 ${animeList.length} 个动画');
        return animeList;
      } else {
        print('BangumiAPI: 请求失败，状态码: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('BangumiAPI: 获取当季动画失败: $e');
      return [];
    }
  }
  
  /// 获取热门动画排行
  Future<List<Anime>> getPopularAnime({int limit = 20}) async {
    try {
      print('BangumiAPI: 获取热门动画排行');
      
      // 使用search API搜索高评分动画
      final url = '$_baseUrl/search/subject/动画?type=2&responseGroup=large&max_results=$limit';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Anime> animeList = [];
        
        if (data['list'] != null) {
          for (final item in data['list']) {
            final anime = _parseAnimeFromBangumi(item);
            if (anime != null) {
              animeList.add(anime);
            }
          }
        }
        
        print('BangumiAPI: 成功获取 ${animeList.length} 个热门动画');
        return animeList;
      } else {
        print('BangumiAPI: 请求失败，状态码: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('BangumiAPI: 获取热门动画失败: $e');
      return [];
    }
  }
  
  /// 根据关键词搜索动画
  Future<List<Anime>> searchAnime(String keyword, {int limit = 20}) async {
    try {
      print('BangumiAPI: 搜索动画关键词: $keyword');
      
      final encodedKeyword = Uri.encodeComponent(keyword);
      final url = '$_baseUrl/search/subject/$encodedKeyword?type=2&responseGroup=large&max_results=$limit';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Anime> animeList = [];
        
        if (data['list'] != null) {
          final List<Map<String, dynamic>> scoredResults = [];
          
          for (final item in data['list']) {
            final anime = _parseAnimeFromBangumi(item);
            if (anime != null) {
              // 计算相关性评分
              final score = _calculateRelevanceScore(anime, keyword);
              if (score > 0) { // 只保留有相关性的结果
                scoredResults.add({
                  'anime': anime,
                  'score': score,
                });
              }
            }
          }
          
          // 按相关性评分排序
          scoredResults.sort((a, b) => b['score'].compareTo(a['score']));
          
          // 提取排序后的动画列表
          for (final result in scoredResults.take(limit)) {
            animeList.add(result['anime'] as Anime);
          }
        }
        
        print('BangumiAPI: 搜索到 ${animeList.length} 个相关动画（已按相关性排序）');
        return animeList;
      } else {
        print('BangumiAPI: 搜索失败，状态码: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('BangumiAPI: 搜索动画失败: $e');
      return [];
    }
  }
  
  /// 计算搜索结果的相关性评分
  double _calculateRelevanceScore(Anime anime, String keyword) {
    double score = 0.0;
    final lowerKeyword = keyword.toLowerCase();
    final lowerTitle = anime.title.toLowerCase();
    
    // 完全匹配得分最高
    if (lowerTitle == lowerKeyword) {
      score += 100.0;
    }
    // 标题开头匹配
    else if (lowerTitle.startsWith(lowerKeyword)) {
      score += 80.0;
    }
    // 标题包含关键词
    else if (lowerTitle.contains(lowerKeyword)) {
      score += 60.0;
    }
    
    // 检查关键词的各个部分
    final keywordParts = lowerKeyword.split(RegExp(r'[\s\-_]+'));
    int matchedParts = 0;
    
    for (final part in keywordParts) {
      if (part.isNotEmpty && lowerTitle.contains(part)) {
        matchedParts++;
        score += 20.0;
      }
    }
    
    // 如果关键词有多个部分，要求至少匹配一半
    if (keywordParts.length > 1) {
      final matchRatio = matchedParts / keywordParts.length;
      if (matchRatio < 0.5) {
        score *= 0.3; // 大幅降低评分
      }
    }
    
    // 评分加成：根据评分和年份
    if (anime.rating > 8.0) {
      score += 10.0;
    } else if (anime.rating > 7.0) {
      score += 5.0;
    }
    
    // 较新的动画稍微加分
    final currentYear = DateTime.now().year;
    if (anime.year >= currentYear - 2) {
      score += 5.0;
    }
    
    // 过滤掉评分过低的结果
    if (score < 20.0) {
      return 0.0; // 不相关
    }
    
    return score;
  }
  
  /// 判断是否为日本动漫
  bool _isJapaneseAnime(Map<String, dynamic> item, String name, String nameCn, String summary) {
    // 1. 检查制作国家/地区信息
    if (item['infobox'] != null) {
      for (final info in item['infobox']) {
        if (info['key'] == '制作' || info['key'] == '动画制作' || info['key'] == '制作国家/地区') {
          final value = info['value']?.toString().toLowerCase() ?? '';
          if (value.contains('日本') || value.contains('japan')) {
            return true;
          }
          if (value.contains('中国') || value.contains('china') || 
              value.contains('韩国') || value.contains('korea') ||
              value.contains('美国') || value.contains('america')) {
            return false;
          }
        }
      }
    }
    
    // 2. 检查标题特征
    // 日文假名和汉字混合的标题通常是日漫
    final RegExp japanesePattern = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]'); // 平假名和片假名
    if (japanesePattern.hasMatch(name)) {
      return true;
    }
    
    // 3. 检查常见的日漫制作公司
    final japaneseStudios = [
      'toei', 'madhouse', 'studio pierrot', 'bones', 'mappa', 'wit studio',
      'a-1 pictures', 'shaft', 'kyoani', 'trigger', 'gainax', 'sunrise',
      'production i.g', 'j.c.staff', 'doga kobo', 'white fox', 'cloverworks'
    ];
    
    final lowerSummary = summary.toLowerCase();
    final lowerName = name.toLowerCase();
    
    for (final studio in japaneseStudios) {
      if (lowerSummary.contains(studio) || lowerName.contains(studio)) {
        return true;
      }
    }
    
    // 4. 排除明显的非日漫关键词
    final nonJapaneseKeywords = [
      '中国', '国产', '国漫', '中华', '大陆',
      '韩国', '韩漫', 
      '美国', '美漫', 'disney', 'pixar', 'dreamworks',
      '欧洲', '法国', '英国'
    ];
    
    for (final keyword in nonJapaneseKeywords) {
      if (lowerSummary.contains(keyword) || lowerName.contains(keyword) || nameCn.contains(keyword)) {
        return false;
      }
    }
    
    // 5. 默认情况下，如果没有明确的非日漫标识，则认为是日漫
    // 因为Bangumi主要收录日漫内容
    return true;
  }
  
  /// 获取动漫详细信息
  Future<Anime?> getAnimeDetail(String bangumiId) async {
    try {
      print('BangumiAPI: 获取动漫详情 ID: $bangumiId');
      
      final url = '$_baseUrl/v0/subjects/$bangumiId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseDetailedAnimeFromBangumi(data);
      } else {
        print('BangumiAPI: 获取详情失败，状态码: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('BangumiAPI: 获取动漫详情失败: $e');
      return null;
    }
  }

  /// 解析详细的Bangumi动漫数据
  Anime? _parseDetailedAnimeFromBangumi(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? item['name_cn'] ?? '未知标题';
      final nameCn = item['name_cn'] ?? name;
      final summary = item['summary'] ?? '';
      
      // 检查是否为日漫
      if (!_isJapaneseAnime(item, name, nameCn, summary)) {
        return null; // 过滤掉非日漫
      }
      
      String imageUrl = '';
      if (item['images'] != null) {
        final images = item['images'];
        imageUrl = images['large'] ?? images['medium'] ?? images['small'] ?? '';
        
        // 验证图片URL
        if (imageUrl.isNotEmpty) {
          try {
            final uri = Uri.parse(imageUrl);
            if (!uri.hasScheme || uri.host.isEmpty || uri.host == 'img.test.com') {
              imageUrl = ''; // 清空无效URL
            }
          } catch (e) {
            imageUrl = ''; // 清空无效URL
          }
        }
      }
      
      final rating = item['rating']?['score']?.toDouble() ?? 0.0;
      final airDate = item['air_date'] ?? '';
      final eps = item['eps'] ?? 0;
      final totalEpisodes = item['total_episodes'] ?? eps;
      
      // 从infobox提取更多信息
      final List<String> tags = [];
      final List<String> genres = [];
      String detailedDescription = summary;
      
      if (item['infobox'] != null) {
        for (final info in item['infobox']) {
          final key = info['key']?.toString() ?? '';
          final value = info['value']?.toString() ?? '';
          
          switch (key) {
            case '类型':
            case '题材':
            case '标签':
              if (value.isNotEmpty) {
                final genreList = value.split(RegExp(r'[,，、]'));
                for (final genre in genreList) {
                  final cleanGenre = genre.trim();
                  if (cleanGenre.isNotEmpty && !genres.contains(cleanGenre)) {
                    genres.add(cleanGenre);
                  }
                }
              }
              break;
            case '话数':
            case '集数':
              if (value.isNotEmpty && eps == 0) {
                try {
                  final episodeCount = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
                  if (episodeCount != null && episodeCount > 0) {
                    tags.add('$episodeCount话');
                  }
                } catch (e) {
                  // 忽略解析错误
                }
              }
              break;
            case '放送开始':
            case '播放日期':
              if (value.isNotEmpty && airDate.isEmpty) {
                tags.add('播出: $value');
              }
              break;
            case '制作':
            case '动画制作':
              if (value.isNotEmpty) {
                tags.add('制作: $value');
              }
              break;
          }
        }
      }
      
      // 添加评分和收藏信息
      if (rating > 0) {
        tags.add('评分: ${rating.toStringAsFixed(1)}');
      }
      if (item['collection'] != null) {
        final collect = item['collection']['collect'] ?? 0;
        if (collect > 0) {
          tags.add('收藏: $collect');
        }
      }
      if (totalEpisodes > 0) {
        tags.add('$totalEpisodes话');
      }
      
      // 增强简介信息
      if (detailedDescription.isEmpty || detailedDescription == '暂无简介') {
        if (genres.isNotEmpty) {
          detailedDescription = '类型：${genres.join('、')}\n\n';
        }
        if (item['staff'] != null && item['staff'].isNotEmpty) {
          detailedDescription += '制作信息：\n';
          for (final staff in item['staff'].take(3)) {
            final name = staff['name'] ?? '';
            final jobs = staff['jobs'] ?? [];
            if (name.isNotEmpty && jobs.isNotEmpty) {
              detailedDescription += '${jobs.join('、')}：$name\n';
            }
          }
        }
        if (detailedDescription.isEmpty) {
          detailedDescription = '这是一部来自Bangumi的${genres.isNotEmpty ? genres.first : ''}动画作品。';
        }
      }
      
      return Anime(
        id: 'bangumi_$id',
        title: nameCn.isNotEmpty ? nameCn : name,
        imageUrl: imageUrl,
        detailUrl: 'https://bgm.tv/subject/$id',
        description: detailedDescription,
        tags: tags,
        genres: genres,
        rating: rating,
        year: _extractYearFromDate(airDate),
        status: _getStatusFromAirDate(airDate),
        episodeCount: totalEpisodes,
        episodes: totalEpisodes, // 确保两个字段都设置
        source: 'Bangumi',
      );
    } catch (e) {
      print('BangumiAPI: 解析详细动画数据失败: $e');
      return null;
    }
  }

  /// 解析Bangumi API返回的动画数据
  Anime? _parseAnimeFromBangumi(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? item['name_cn'] ?? '未知标题';
      final nameCn = item['name_cn'] ?? name;
      final summary = item['summary'] ?? '';
      
      // 检查是否为日漫
      if (!_isJapaneseAnime(item, name, nameCn, summary)) {
        return null; // 过滤掉非日漫
      }
      
      String imageUrl = '';
      if (item['images'] != null) {
        final images = item['images'];
        imageUrl = images['large'] ?? images['medium'] ?? images['small'] ?? '';
        
        // 验证图片URL
        if (imageUrl.isNotEmpty) {
          try {
            final uri = Uri.parse(imageUrl);
            if (!uri.hasScheme || uri.host.isEmpty || uri.host == 'img.test.com') {
              imageUrl = ''; // 清空无效URL
            }
          } catch (e) {
            imageUrl = ''; // 清空无效URL
          }
        }
      }
      final rating = item['rating']?['score']?.toDouble() ?? 0.0;
      final airDate = item['air_date'] ?? '';
      final eps = item['eps'] ?? 0;
      
      // 处理标签
      final List<String> tags = [];
      if (item['collection'] != null) {
        tags.add('收藏: ${item['collection']['collect']}');
      }
      if (rating > 0) {
        tags.add('评分: ${rating.toStringAsFixed(1)}');
      }
      if (eps > 0) {
        tags.add('$eps话');
      }
      
      return Anime(
        id: 'bangumi_$id',
        title: nameCn.isNotEmpty ? nameCn : name,
        imageUrl: imageUrl,
        detailUrl: 'https://bgm.tv/subject/$id',
        description: summary.isNotEmpty ? summary : '暂无简介',
        tags: tags,
        rating: rating,
        year: _extractYearFromDate(airDate),
        status: _getStatusFromAirDate(airDate),
        episodeCount: eps,
        episodes: eps, // 确保两个字段都设置
        source: 'Bangumi',
      );
    } catch (e) {
      print('BangumiAPI: 解析动画数据失败: $e');
      return null;
    }
  }
  
  /// 从日期字符串提取年份
  int _extractYearFromDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().year;
    
    try {
      final regex = RegExp(r'(\d{4})');
      final match = regex.firstMatch(dateStr);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      print('BangumiAPI: 解析年份失败: $e');
    }
    
    return DateTime.now().year;
  }
  
  /// 根据播出日期判断状态
  String _getStatusFromAirDate(String dateStr) {
    if (dateStr.isEmpty) return '未知';
    
    try {
      final now = DateTime.now();
      final airDate = DateTime.tryParse(dateStr);
      
      if (airDate != null) {
        if (airDate.isAfter(now)) {
          return '即将播出';
        } else if (airDate.year == now.year) {
          return '正在播出';
        } else {
          return '已完结';
        }
      }
    } catch (e) {
      print('BangumiAPI: 解析状态失败: $e');
    }
    
    return '已完结';
  }
}
