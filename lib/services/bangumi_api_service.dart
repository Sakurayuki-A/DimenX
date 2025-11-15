import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';

/// 缓存项
class _CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration expiry;
  
  _CacheItem(this.data, this.expiry) : timestamp = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
}

/// 简化的Bangumi API服务（带缓存）
class BangumiApiService {
  static const String _baseUrl = 'https://api.bgm.tv';
  static const String _userAgent = 'AnimeHUBX/1.0.0';
  static const Duration _timeout = Duration(seconds: 10);
  
  // 内存缓存
  static final Map<String, _CacheItem<List<Anime>>> _animeListCache = {};
  static final Map<String, _CacheItem<Anime>> _animeDetailCache = {};
  
  // 缓存过期时间
  static const Duration _seasonalCacheExpiry = Duration(hours: 2);
  static const Duration _searchCacheExpiry = Duration(minutes: 30);
  static const Duration _detailCacheExpiry = Duration(hours: 6);
  
  /// 获取当季动画（带缓存）
  Future<List<Anime>> getSeasonalAnime({int limit = 20}) async {
    final cacheKey = 'seasonal_$limit';
    
    // 检查缓存
    if (_animeListCache.containsKey(cacheKey)) {
      final cached = _animeListCache[cacheKey]!;
      if (!cached.isExpired) {
        print('使用缓存的当季动画数据');
        return cached.data;
      } else {
        _animeListCache.remove(cacheKey);
      }
    }
    
    try {
      print('从API获取当季动画数据');
      final response = await http.get(
        Uri.parse('$_baseUrl/calendar'),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> weeklyData = json.decode(response.body);
        final List<Anime> animeList = [];
        
        for (final dayData in weeklyData) {
          if (dayData['items'] != null) {
            for (final item in dayData['items']) {
              if (item['type'] == 2 && animeList.length < limit) {
                final anime = _parseAnime(item);
                if (anime != null) animeList.add(anime);
              }
            }
          }
        }
        
        // 缓存结果
        _animeListCache[cacheKey] = _CacheItem(animeList, _seasonalCacheExpiry);
        print('当季动画数据已缓存，${animeList.length}个结果');
        
        return animeList;
      }
    } catch (e) {
      print('获取当季动画失败: $e');
    }
    return [];
  }
  
  /// 搜索动画（带缓存）
  Future<List<Anime>> searchAnime(String keyword, {int limit = 20}) async {
    if (keyword.trim().isEmpty) return [];
    
    final cacheKey = 'search_${keyword.trim()}_$limit';
    
    // 检查缓存
    if (_animeListCache.containsKey(cacheKey)) {
      final cached = _animeListCache[cacheKey]!;
      if (!cached.isExpired) {
        print('使用缓存的搜索结果: $keyword');
        return cached.data;
      } else {
        _animeListCache.remove(cacheKey);
      }
    }
    
    try {
      print('从API搜索动画: $keyword');
      final encodedKeyword = Uri.encodeComponent(keyword.trim());
      final response = await http.get(
        Uri.parse('$_baseUrl/search/subject/$encodedKeyword?type=2&max_results=$limit'),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Anime> animeList = [];
        
        if (data['list'] != null) {
          for (final item in data['list']) {
            final anime = _parseAnime(item);
            if (anime != null) animeList.add(anime);
          }
        }
        
        // 缓存结果
        _animeListCache[cacheKey] = _CacheItem(animeList, _searchCacheExpiry);
        print('搜索结果已缓存: $keyword，${animeList.length}个结果');
        
        return animeList;
      }
    } catch (e) {
      print('搜索动画失败: $e');
    }
    return [];
  }
  
  /// 获取动画详情（带缓存）
  Future<Anime?> getAnimeDetail(String bangumiId) async {
    final cacheKey = 'detail_$bangumiId';
    
    // 检查缓存
    if (_animeDetailCache.containsKey(cacheKey)) {
      final cached = _animeDetailCache[cacheKey]!;
      if (!cached.isExpired) {
        print('使用缓存的动画详情: $bangumiId');
        return cached.data;
      } else {
        _animeDetailCache.remove(cacheKey);
      }
    }
    
    try {
      print('从API获取动画详情: $bangumiId');
      final response = await http.get(
        Uri.parse('$_baseUrl/v0/subjects/$bangumiId'),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final anime = _parseAnime(data);
        
        if (anime != null) {
          // 缓存结果
          _animeDetailCache[cacheKey] = _CacheItem(anime, _detailCacheExpiry);
          print('动画详情已缓存: $bangumiId');
        }
        
        return anime;
      }
    } catch (e) {
      print('获取动画详情失败: $e');
    }
    return null;
  }
  
  /// 解析动画数据
  Anime? _parseAnime(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? item['name_cn'] ?? '未知标题';
      final nameCn = item['name_cn'] ?? name;
      final summary = item['summary'] ?? '';
      
      // 获取图片URL
      String imageUrl = '';
      if (item['images'] != null) {
        final images = item['images'];
        imageUrl = images['large'] ?? images['medium'] ?? images['small'] ?? '';
      }
      
      final rating = item['rating']?['score']?.toDouble() ?? 0.0;
      final airDate = item['air_date'] ?? '';
      final eps = item['eps'] ?? item['total_episodes'] ?? 0;
      final year = _extractYear(airDate);
      
      return Anime(
        id: 'bangumi_$id',
        title: nameCn.isNotEmpty ? nameCn : name,
        imageUrl: imageUrl,
        videoUrl: '', // Bangumi不提供视频链接
        description: summary.isNotEmpty ? summary : '暂无简介',
        episodes: eps,
        status: _getStatus(airDate),
        year: year,
        rating: rating,
        source: 'Bangumi',
      );
    } catch (e) {
      print('解析动画数据失败: $e');
      return null;
    }
  }
  
  /// 提取年份
  int _extractYear(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().year;
    
    final regex = RegExp(r'(\d{4})');
    final match = regex.firstMatch(dateStr);
    return int.tryParse(match?.group(1) ?? '') ?? DateTime.now().year;
  }
  
  /// 获取状态
  String _getStatus(String dateStr) {
    if (dateStr.isEmpty) return '未知';
    
    final airDate = DateTime.tryParse(dateStr);
    if (airDate == null) return '未知';
    
    final now = DateTime.now();
    if (airDate.isAfter(now)) {
      return '即将播出';
    } else if (airDate.year == now.year) {
      return '连载中';
    } else {
      return '已完结';
    }
  }
  
  /// 清理所有缓存
  static void clearAllCache() {
    _animeListCache.clear();
    _animeDetailCache.clear();
    print('BangumiAPI缓存已清理');
  }
  
  /// 清理过期缓存
  static void clearExpiredCache() {
    _animeListCache.removeWhere((key, item) => item.isExpired);
    _animeDetailCache.removeWhere((key, item) => item.isExpired);
    print('BangumiAPI过期缓存已清理');
  }
  
  /// 获取缓存状态
  static Map<String, int> getCacheStats() {
    return {
      'animeListCache': _animeListCache.length,
      'animeDetailCache': _animeDetailCache.length,
      'totalCacheItems': _animeListCache.length + _animeDetailCache.length,
    };
  }
}
