import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
import 'bangumi_api_service.dart';

/// 缓存项
class _CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration expiry;
  
  _CacheItem(this.data, this.expiry) : timestamp = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
}

/// Bangumi番剧时间表服务（优化版）
class BangumiCalendarService {
  static const String _baseUrl = 'https://api.bgm.tv';
  static const Duration _timeout = Duration(seconds: 5);
  static const Duration _cacheExpiry = Duration(hours: 1); // 时间表缓存1小时
  
  // 缓存
  static final Map<String, _CacheItem<Map<int, List<Anime>>>> _calendarCache = {};
  static final Map<String, Future<Map<int, List<Anime>>>> _pendingRequests = {};
  
  // 复用BangumiApiService的详情获取
  final BangumiApiService _apiService = BangumiApiService();
  
  /// 获取单天的番剧数据（快速版）
  Future<List<Anime>> getDayCalendar(int weekday) async {
    // 先尝试从缓存获取完整时间表
    final calendar = await getCalendar();
    if (calendar.containsKey(weekday)) {
      return calendar[weekday]!;
    }
    return [];
  }

  /// 获取指定年份和季度的番剧时间表（带缓存和请求去重）
  Future<Map<int, List<Anime>>> getCalendar({
    int? year,
    int? month,
  }) async {
    final cacheKey = 'calendar_${year ?? 'all'}_${month ?? 'all'}';
    
    // 1. 检查缓存
    if (_calendarCache.containsKey(cacheKey)) {
      final cached = _calendarCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的时间表数据');
        return cached.data;
      } else {
        _calendarCache.remove(cacheKey);
      }
    }
    
    // 2. 检查是否有正在进行的请求
    if (_pendingRequests.containsKey(cacheKey)) {
      print('⏳ 等待正在进行的时间表请求...');
      return await _pendingRequests[cacheKey]!;
    }
    
    // 3. 创建新请求
    final requestFuture = _fetchCalendar(year: year, month: month, cacheKey: cacheKey);
    _pendingRequests[cacheKey] = requestFuture;
    
    try {
      final result = await requestFuture;
      return result;
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }
  
  /// 实际执行获取时间表的请求
  Future<Map<int, List<Anime>>> _fetchCalendar({
    int? year,
    int? month,
    required String cacheKey,
  }) async {
    try {
      print('🌐 从API获取时间表数据...');
      final startTime = DateTime.now();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/calendar'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0.0 (https://github.com/your-repo)',
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final result = await _parseCalendarData(data, year: year, month: month);
        
        // 缓存结果
        _calendarCache[cacheKey] = _CacheItem(result, _cacheExpiry);
        
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        print('✓ 时间表数据获取完成，耗时: ${elapsed}ms');
        
        return result;
      } else {
        print('✗ HTTP ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('✗ 获取时间表失败: $e');
      return {};
    }
  }



  /// 解析时间表数据（快速版：只解析基本信息）
  Future<Map<int, List<Anime>>> _parseCalendarData(List<dynamic> data, {int? year, int? month}) async {
    final calendar = <int, List<Anime>>{};
    
    try {
      for (int i = 0; i < data.length; i++) {
        final dayData = data[i];
        final weekday = dayData['weekday']?['id'] ?? (i + 1);
        final items = dayData['items'] as List<dynamic>? ?? [];
        
        final dayAnime = <Anime>[];
        
        // 快速解析基本信息，不请求详情
        for (final item in items.take(20)) { // 增加到20个
          final anime = _parseAnimeBasicInfo(item, year: year, month: month);
          if (anime != null) {
            dayAnime.add(anime);
            
            // 异步预加载详情（不阻塞）
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              _apiService.preloadAnimeDetail(id);
            }
          }
        }
        
        // 按评分排序
        dayAnime.sort((a, b) => b.rating.compareTo(a.rating));
        calendar[weekday] = dayAnime;
      }
      
      print('✓ 解析完成，共 ${calendar.length} 天的数据');
      return calendar;
    } catch (e) {
      print('✗ 解析时间表数据失败: $e');
      return {};
    }
  }
  
  /// 解析基本信息（不请求详情API，速度快）
  Anime? _parseAnimeBasicInfo(Map<String, dynamic> item, {int? year, int? month}) {
    try {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? '';
      final nameCn = item['name_cn'] ?? '';
      final airDate = item['air_date'] ?? '';
      final eps = item['eps'] ?? 0;
      final rating = (item['rating']?['score'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = item['rating']?['total'] ?? 0;
      final rank = item['rank'];
      
      // 过滤条件
      if (year != null && month != null) {
        if (!_isInTargetPeriod(airDate, year, month)) {
          return null;
        }
      }
      
      // 获取图片URL
      String imageUrl = '';
      final images = item['images'];
      if (images != null) {
        imageUrl = images['large'] ?? images['medium'] ?? images['small'] ?? '';
      }
      
      // 生成简洁描述（不需要详情API）
      final description = _generateQuickDescription(airDate, eps, rating, ratingCount);
      
      // 获取标签
      final tags = <String>[];
      if (rating > 0) {
        tags.add('★ ${rating.toStringAsFixed(1)}');
      }
      if (ratingCount > 0) {
        tags.add('${ratingCount}人评分');
      }
      if (eps > 0) {
        tags.add('${eps}话');
      }
      
      return Anime(
        id: 'bangumi_calendar_$id',
        title: nameCn.isNotEmpty ? nameCn : name,
        imageUrl: imageUrl,
        detailUrl: 'https://bgm.tv/subject/$id',
        description: description,
        tags: tags,
        rating: rating,
        year: _extractYearFromDate(airDate),
        status: _getStatusFromAirDate(airDate),
        episodeCount: eps,
        episodes: eps,
        airDate: airDate,
        rank: rank,
        source: 'Bangumi',
      );
    } catch (e) {
      print('✗ 解析番剧基本信息失败: $e');
      return null;
    }
  }
  
  /// 生成快速描述（不需要详情API）
  String _generateQuickDescription(String airDate, int eps, double rating, int ratingCount) {
    final parts = <String>[];
    
    // 播出日期
    if (airDate.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(airDate);
        parts.add('${dateTime.year}年${dateTime.month}月${dateTime.day}日播出');
      } catch (e) {
        if (airDate.length >= 4) {
          parts.add('${airDate.substring(0, 4)}年播出');
        }
      }
    }
    
    // 集数
    if (eps > 0) {
      parts.add('共${eps}话');
    }
    
    // 评分信息
    if (rating > 0) {
      parts.add('评分${rating.toStringAsFixed(1)}');
      if (ratingCount > 0) {
        parts.add('${ratingCount}人评价');
      }
    }
    
    return parts.isNotEmpty ? parts.join(' · ') : '暂无详细信息';
  }


  /// 检查是否在目标时间段内
  bool _isInTargetPeriod(String airDate, int year, int month) {
    if (airDate.isEmpty) return true;
    
    try {
      final date = DateTime.parse(airDate);
      return date.year == year && date.month == month;
    } catch (e) {
      return true; // 解析失败时包含
    }
  }


  /// 从日期字符串提取年份
  int _extractYearFromDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().year;
    
    try {
      final date = DateTime.parse(dateStr);
      return date.year;
    } catch (e) {
      // 尝试提取年份数字
      final yearMatch = RegExp(r'(\d{4})').firstMatch(dateStr);
      if (yearMatch != null) {
        return int.parse(yearMatch.group(1)!);
      }
      return DateTime.now().year;
    }
  }

  /// 根据播出日期获取状态
  String _getStatusFromAirDate(String airDate) {
    if (airDate.isEmpty) return '未知';
    
    try {
      final date = DateTime.parse(airDate);
      final now = DateTime.now();
      
      if (date.isAfter(now)) {
        return '未播出';
      } else if (date.year == now.year && date.month == now.month) {
        return '正在播出';
      } else {
        return '已完结';
      }
    } catch (e) {
      return '未知';
    }
  }


  /// 获取星期名称
  static String getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '星期一';
      case 2:
        return '星期二';
      case 3:
        return '星期三';
      case 4:
        return '星期四';
      case 5:
        return '星期五';
      case 6:
        return '星期六';
      case 7:
        return '星期日';
      default:
        return '未知';
    }
  }
}
