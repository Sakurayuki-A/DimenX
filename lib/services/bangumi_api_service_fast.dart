import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/anime.dart';

/// 缓存项
class _CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration expiry;
  
  _CacheItem(this.data, this.expiry) : timestamp = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
}

/// 高性能 Bangumi API 服务（参考 Kazumi 优化）
/// 
/// 优化策略：
/// 1. 使用 IOClient 复用 HTTP 连接（Keep-Alive）
/// 2. 配置 HttpClient 参数优化性能
/// 3. 智能缓存和请求去重
/// 4. 随机 User-Agent 避免限流
/// 5. 启用 GZIP 压缩
/// 6. 优化超时时间
/// 7. 使用 next.bgm.tv API（更快）
class BangumiApiServiceFast {
  static const String _baseUrl = 'https://api.bgm.tv';
  static const String _nextBaseUrl = 'https://next.bgm.tv';
  static const Duration _timeout = Duration(seconds: 8);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  
  // 随机 User-Agent 列表（参考 Kazumi）
  static final List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
    'AnimeHUBX/1.0.0 (https://github.com/dimenx)',
  ];
  
  static String _getRandomUserAgent() {
    return _userAgents[Random().nextInt(_userAgents.length)];
  }
  
  // 使用 IOClient 包装 HttpClient，支持连接复用
  static http.Client? _client;
  static http.Client get client {
    if (_client == null) {
      final httpClient = HttpClient()
        ..connectionTimeout = _connectionTimeout
        ..idleTimeout = const Duration(seconds: 60) // 保持连接60秒
        ..maxConnectionsPerHost = 10 // 每个主机最多10个连接
        ..autoUncompress = true; // 自动解压 GZIP
      
      _client = IOClient(httpClient);
      print('✓ HTTP Client 已初始化（启用连接复用 + GZIP）');
    }
    return _client!;
  }
  
  // 内存缓存
  static final Map<String, _CacheItem<List<Anime>>> _animeListCache = {};
  static final Map<String, _CacheItem<Anime>> _animeDetailCache = {};
  
  // 正在进行的请求（防止重复请求）
  static final Map<String, Future<List<Anime>>> _pendingListRequests = {};
  static final Map<String, Future<Anime?>> _pendingDetailRequests = {};
  
  // 缓存过期时间
  static const Duration _seasonalCacheExpiry = Duration(hours: 2);
  static const Duration _searchCacheExpiry = Duration(minutes: 30);
  static const Duration _detailCacheExpiry = Duration(hours: 6);
  
  /// 获取热门动画（使用 next.bgm.tv 的 trends API，更快）
  static Future<List<Anime>> getHotAnime({int limit = 20}) async {
    final cacheKey = 'hot_anime_trends_$limit';
    
    // 1. 检查缓存
    if (_animeListCache.containsKey(cacheKey)) {
      final cached = _animeListCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的热门动画数据');
        return cached.data;
      } else {
        _animeListCache.remove(cacheKey);
      }
    }
    
    // 2. 检查是否有正在进行的相同请求
    if (_pendingListRequests.containsKey(cacheKey)) {
      print('⏳ 等待正在进行的热门动画请求...');
      return await _pendingListRequests[cacheKey]!;
    }
    
    // 3. 创建新请求
    final requestFuture = _fetchHotAnimeFromTrends(limit, cacheKey);
    _pendingListRequests[cacheKey] = requestFuture;
    
    try {
      final result = await requestFuture;
      return result;
    } finally {
      _pendingListRequests.remove(cacheKey);
    }
  }
  
  /// 从 trends API 获取热门动画（参考 Kazumi）
  static Future<List<Anime>> _fetchHotAnimeFromTrends(int limit, String cacheKey) async {
    try {
      print('🔥 从 Trends API 获取热门动画数据...');
      final startTime = DateTime.now();
      
      // 使用 next.bgm.tv 的 trends API（参考 Kazumi）
      final response = await client.get(
        Uri.parse('$_nextBaseUrl/p1/trending/subjects?type=2&limit=$limit&offset=0'),
        headers: {
          'User-Agent': _getRandomUserAgent(),
          'Accept': 'application/json',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate, br',
        },
      ).timeout(_timeout);
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Anime> animeList = [];
        
        if (data['data'] != null) {
          for (final item in data['data']) {
            if (item['subject'] != null) {
              final anime = _parseAnime(item['subject']);
              if (anime != null) animeList.add(anime);
            }
          }
        }
        
        // 缓存结果
        _animeListCache[cacheKey] = _CacheItem(animeList, _seasonalCacheExpiry);
        print('✓ 热门动画数据已缓存，${animeList.length}个结果，耗时: ${elapsed}ms');
        
        return animeList;
      } else if (response.statusCode == 429) {
        print('✗ API请求频率限制，尝试使用 Calendar API');
        // 降级到 Calendar API
        return _fetchHotAnimeFromCalendar(limit, cacheKey);
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ 获取热门动画失败，尝试降级: $e');
      // 降级到 Calendar API
      return _fetchHotAnimeFromCalendar(limit, cacheKey);
    }
  }
  
  /// 从时间表获取热门动画（降级方案）
  static Future<List<Anime>> _fetchHotAnimeFromCalendar(int limit, String cacheKey) async {
    try {
      print('📅 使用 Calendar API 作为降级方案...');
      final startTime = DateTime.now();
      
      final response = await client.get(
        Uri.parse('$_nextBaseUrl/p1/calendar'),
        headers: {
          'User-Agent': _getRandomUserAgent(),
          'Accept': 'application/json',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate, br',
        },
      ).timeout(_timeout);
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response.statusCode == 200) {
        final List<dynamic> weeklyData = json.decode(response.body);
        final List<Anime> allAnimeList = [];
        
        for (final dayData in weeklyData) {
          if (dayData['items'] != null) {
            for (final item in dayData['items']) {
              if (item['subject'] != null && item['subject']['type'] == 2) {
                final anime = _parseAnime(item['subject']);
                if (anime != null) allAnimeList.add(anime);
              }
            }
          }
        }
        
        // 按评分排序
        allAnimeList.sort((a, b) {
          final ratingCompare = b.rating.compareTo(a.rating);
          if (ratingCompare != 0) return ratingCompare;
          if (a.rank != null && b.rank != null) {
            return a.rank!.compareTo(b.rank!);
          }
          return 0;
        });
        
        final hotAnimeList = allAnimeList.take(limit).toList();
        
        // 缓存结果
        _animeListCache[cacheKey] = _CacheItem(hotAnimeList, _seasonalCacheExpiry);
        print('✓ 热门动画数据已缓存（Calendar），${hotAnimeList.length}个结果，耗时: ${elapsed}ms');
        
        return hotAnimeList;
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ Calendar API 也失败: $e');
      rethrow;
    }
  }
  
  /// 搜索动画（使用 v0 search API）
  static Future<List<Anime>> searchAnime(String keyword, {int limit = 20}) async {
    if (keyword.trim().isEmpty) return [];
    
    final cacheKey = 'search_${keyword.trim()}_$limit';
    
    // 1. 检查缓存
    if (_animeListCache.containsKey(cacheKey)) {
      final cached = _animeListCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的搜索结果: $keyword');
        return cached.data;
      } else {
        _animeListCache.remove(cacheKey);
      }
    }
    
    // 2. 检查是否有正在进行的相同搜索请求
    if (_pendingListRequests.containsKey(cacheKey)) {
      print('⏳ 等待正在进行的搜索请求完成: $keyword');
      return await _pendingListRequests[cacheKey]!;
    }
    
    // 3. 创建新搜索请求
    final requestFuture = _fetchSearchResults(keyword, limit, cacheKey);
    _pendingListRequests[cacheKey] = requestFuture;
    
    try {
      final result = await requestFuture;
      return result;
    } finally {
      _pendingListRequests.remove(cacheKey);
    }
  }
  
  /// 实际执行搜索请求
  static Future<List<Anime>> _fetchSearchResults(String keyword, int limit, String cacheKey) async {
    try {
      print('🔍 从API搜索动画: $keyword');
      final startTime = DateTime.now();
      final encodedKeyword = Uri.encodeComponent(keyword.trim());
      
      final response = await client.get(
        Uri.parse('$_baseUrl/search/subject/$encodedKeyword?type=2&max_results=$limit'),
        headers: {
          'User-Agent': _getRandomUserAgent(),
          'Accept': 'application/json',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate, br',
        },
      ).timeout(_timeout);
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
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
        print('✓ 搜索结果已缓存: $keyword，${animeList.length}个结果，耗时: ${elapsed}ms');
        
        return animeList;
      } else if (response.statusCode == 429) {
        throw Exception('API请求频率限制');
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ 搜索动画失败: $e');
      rethrow;
    }
  }
  
  /// 获取动画详情
  static Future<Anime?> getAnimeDetail(String bangumiId) async {
    final cacheKey = 'detail_$bangumiId';
    
    // 1. 检查缓存
    if (_animeDetailCache.containsKey(cacheKey)) {
      final cached = _animeDetailCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的动画详情: $bangumiId');
        return cached.data;
      } else {
        _animeDetailCache.remove(cacheKey);
      }
    }
    
    // 2. 检查是否有正在进行的相同详情请求
    if (_pendingDetailRequests.containsKey(cacheKey)) {
      print('⏳ 等待正在进行的详情请求完成: $bangumiId');
      return await _pendingDetailRequests[cacheKey]!;
    }
    
    // 3. 创建新详情请求
    final requestFuture = _fetchAnimeDetail(bangumiId, cacheKey);
    _pendingDetailRequests[cacheKey] = requestFuture;
    
    try {
      final result = await requestFuture;
      return result;
    } finally {
      _pendingDetailRequests.remove(cacheKey);
    }
  }
  
  /// 实际执行获取详情的请求
  static Future<Anime?> _fetchAnimeDetail(String bangumiId, String cacheKey) async {
    try {
      print('📖 从API获取动画详情: $bangumiId');
      final startTime = DateTime.now();
      
      final response = await client.get(
        Uri.parse('$_baseUrl/v0/subjects/$bangumiId'),
        headers: {
          'User-Agent': _getRandomUserAgent(),
          'Accept': 'application/json',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate, br',
        },
      ).timeout(_timeout);
      
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      if (response.statusCode == 200) {
        print('✓ 获取详情成功，耗时: ${elapsed}ms');
        
        final data = json.decode(response.body);
        final anime = _parseAnime(data);
        
        if (anime != null) {
          _animeDetailCache[cacheKey] = _CacheItem(anime, _detailCacheExpiry);
          print('✓ 动画详情已缓存: $bangumiId');
        }
        
        return anime;
      } else if (response.statusCode == 404) {
        print('✗ 动画不存在: $bangumiId');
        return null;
      } else if (response.statusCode == 429) {
        throw Exception('API请求频率限制');
      } else {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ 获取动画详情失败: $e');
      rethrow;
    }
  }
  
  /// 解析动画数据
  static Anime? _parseAnime(Map<String, dynamic> item) {
    try {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? item['name_cn'] ?? '未知标题';
      final nameCn = item['name_cn'] ?? name;
      final summary = item['summary'] ?? '';
      
      String imageUrl = '';
      if (item['images'] != null) {
        final images = item['images'];
        imageUrl = images['large'] ?? images['medium'] ?? images['small'] ?? '';
      }
      
      final rating = item['rating']?['score']?.toDouble() ?? 0.0;
      final rank = item['rating']?['rank'] ?? item['rank'];
      final airDate = item['air_date'] ?? item['date'] ?? '';
      final eps = item['eps'] ?? item['total_episodes'] ?? 0;
      final year = _extractYear(airDate);
      
      List<String> tags = [];
      if (item['tags'] != null && item['tags'] is List) {
        tags = (item['tags'] as List)
            .map((tag) => tag['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      }
      
      return Anime(
        id: 'bangumi_$id',
        title: nameCn.isNotEmpty ? nameCn : name,
        imageUrl: imageUrl,
        videoUrl: '',
        description: summary.isNotEmpty ? summary : '暂无简介',
        episodes: eps,
        status: _getStatus(airDate),
        year: year,
        rating: rating,
        rank: rank,
        tags: tags,
        airDate: airDate,
        source: 'Bangumi',
      );
    } catch (e) {
      print('解析动画数据失败: $e');
      return null;
    }
  }
  
  static int _extractYear(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().year;
    final regex = RegExp(r'(\d{4})');
    final match = regex.firstMatch(dateStr);
    return int.tryParse(match?.group(1) ?? '') ?? DateTime.now().year;
  }
  
  static String _getStatus(String dateStr) {
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
  
  /// 获取缓存统计
  static Map<String, dynamic> getCacheStats() {
    return {
      'listCache': _animeListCache.length,
      'detailCache': _animeDetailCache.length,
      'totalCacheItems': _animeListCache.length + _animeDetailCache.length,
      'pendingListRequests': _pendingListRequests.length,
      'pendingDetailRequests': _pendingDetailRequests.length,
    };
  }
  
  /// 关闭客户端（应用退出时调用）
  static void dispose() {
    _client?.close();
    _client = null;
    _animeListCache.clear();
    _animeDetailCache.clear();
    _pendingListRequests.clear();
    _pendingDetailRequests.clear();
    print('HTTP Client 已关闭，缓存已清理');
  }
}
