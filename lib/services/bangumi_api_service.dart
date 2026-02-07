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

/// 简化的Bangumi API服务（带缓存和请求去重）
class BangumiApiService {
  static const String _baseUrl = 'https://api.bgm.tv';
  static const String _userAgent = 'AnimeHUBX/1.0.0';
  static const Duration _timeout = Duration(seconds: 5); // 减少超时时间
  static const Duration _detailTimeout = Duration(seconds: 3); // 详情页专用超时
  
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
  
  /// 预加载动画详情（不阻塞，静默失败）
  void preloadAnimeDetail(String bangumiId) {
    final cacheKey = 'detail_$bangumiId';
    
    // 如果已经缓存或正在请求，跳过
    if (_animeDetailCache.containsKey(cacheKey) && !_animeDetailCache[cacheKey]!.isExpired) {
      return;
    }
    if (_pendingDetailRequests.containsKey(cacheKey)) {
      return;
    }
    
    // 异步预加载，不等待结果
    print('🔄 预加载动画详情: $bangumiId');
    getAnimeDetail(bangumiId).catchError((e) {
      print('⚠️ 预加载失败（忽略）: $bangumiId');
    });
  }
  
  /// 获取当季动画（带缓存和请求去重）
  Future<List<Anime>> getSeasonalAnime({int limit = 20}) async {
    final cacheKey = 'seasonal_$limit';
    
    // 1. 检查缓存
    if (_animeListCache.containsKey(cacheKey)) {
      final cached = _animeListCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的当季动画数据');
        return cached.data;
      } else {
        _animeListCache.remove(cacheKey);
        print('✗ 缓存已过期，需要重新获取');
      }
    }
    
    // 2. 检查是否有正在进行的相同请求
    if (_pendingListRequests.containsKey(cacheKey)) {
      print('⏳ 等待正在进行的请求完成...');
      return await _pendingListRequests[cacheKey]!;
    }
    
    // 3. 创建新请求
    final requestFuture = _fetchSeasonalAnime(limit, cacheKey);
    _pendingListRequests[cacheKey] = requestFuture;
    
    try {
      final result = await requestFuture;
      return result;
    } finally {
      // 请求完成后移除
      _pendingListRequests.remove(cacheKey);
    }
  }
  
  /// 实际执行获取当季动画的请求
  Future<List<Anime>> _fetchSeasonalAnime(int limit, String cacheKey) async {
    try {
      print('🌐 从API获取当季动画数据...');
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
        print('✓ 当季动画数据已缓存，${animeList.length}个结果');
        
        return animeList;
      } else if (response.statusCode == 429) {
        print('✗ API请求频率限制，请稍后再试');
        throw Exception('API请求频率限制');
      } else {
        print('✗ HTTP请求失败: ${response.statusCode}');
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ 获取当季动画失败: $e');
      rethrow;
    }
  }
  
  /// 获取热门动画（从当季时间表中提取，按评分和收藏数排序）
  /// 
  /// 使用 /calendar 接口获取当季正在播出的热门番剧
  Future<List<Anime>> getHotAnime({int limit = 20}) async {
    final cacheKey = 'hot_anime_calendar_$limit';
    
    // 1. 检查缓存
    if (_animeListCache.containsKey(cacheKey)) {
      final cached = _animeListCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的热门动画数据');
        return cached.data;
      } else {
        _animeListCache.remove(cacheKey);
        print('✗ 热门动画缓存已过期');
      }
    }
    
    // 2. 检查是否有正在进行的相同请求
    if (_pendingListRequests.containsKey(cacheKey)) {
      print('⏳ 等待正在进行的热门动画请求...');
      return await _pendingListRequests[cacheKey]!;
    }
    
    // 3. 创建新请求
    final requestFuture = _fetchHotAnimeFromCalendar(limit, cacheKey);
    _pendingListRequests[cacheKey] = requestFuture;
    
    try {
      final result = await requestFuture;
      return result;
    } finally {
      _pendingListRequests.remove(cacheKey);
    }
  }
  
  /// 从时间表获取热门动画（当季正在播出的番剧）
  Future<List<Anime>> _fetchHotAnimeFromCalendar(int limit, String cacheKey) async {
    try {
      print('🔥 从Calendar API获取热门动画数据...');
      final startTime = DateTime.now();
      
      // 使用Bangumi的时间表接口 GET /calendar
      final response = await http.get(
        Uri.parse('$_baseUrl/calendar'),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final List<dynamic> weeklyData = json.decode(response.body);
        final List<Anime> allAnimeList = [];
        
        // 收集所有星期的动画
        for (final dayData in weeklyData) {
          if (dayData['items'] != null) {
            for (final item in dayData['items']) {
              if (item['type'] == 2) {  // 只要动画类型
                final anime = _parseAnime(item);
                if (anime != null) {
                  allAnimeList.add(anime);
                }
              }
            }
          }
        }
        
        // 按评分和排名综合排序（评分优先，排名作为次要排序）
        allAnimeList.sort((a, b) {
          // 先按评分降序
          final ratingCompare = b.rating.compareTo(a.rating);
          if (ratingCompare != 0) return ratingCompare;
          
          // 评分相同时，按排名升序（排名越小越靠前）
          if (a.rank != null && b.rank != null) {
            return a.rank!.compareTo(b.rank!);
          } else if (a.rank != null) {
            return -1;  // a有排名，b没有，a靠前
          } else if (b.rank != null) {
            return 1;   // b有排名，a没有，b靠前
          }
          return 0;
        });
        
        // 取前N个
        final hotAnimeList = allAnimeList.take(limit).toList();
        
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        
        // 缓存结果
        _animeListCache[cacheKey] = _CacheItem(hotAnimeList, _seasonalCacheExpiry);
        print('✓ 热门动画数据已缓存，从${allAnimeList.length}个番剧中筛选出${hotAnimeList.length}个热门结果，耗时: ${elapsed}ms');
        
        return hotAnimeList;
      } else if (response.statusCode == 429) {
        print('✗ API请求频率限制，请稍后再试');
        throw Exception('API请求频率限制');
      } else {
        print('✗ HTTP请求失败: ${response.statusCode}');
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ 获取热门动画失败: $e');
      rethrow;
    }
  }
  
  /// 搜索动画（带缓存和请求去重）
  Future<List<Anime>> searchAnime(String keyword, {int limit = 20}) async {
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
        print('✗ 搜索缓存已过期: $keyword');
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
      // 请求完成后移除
      _pendingListRequests.remove(cacheKey);
    }
  }
  
  /// 实际执行搜索请求
  Future<List<Anime>> _fetchSearchResults(String keyword, int limit, String cacheKey) async {
    try {
      print('🔍 从API搜索动画: $keyword');
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
        print('✓ 搜索结果已缓存: $keyword，${animeList.length}个结果');
        
        return animeList;
      } else if (response.statusCode == 429) {
        print('✗ API请求频率限制，请稍后再试');
        throw Exception('API请求频率限制');
      } else {
        print('✗ HTTP请求失败: ${response.statusCode}');
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('✗ 搜索动画失败: $e');
      rethrow;
    }
  }
  
  /// 获取动画详情（带缓存和请求去重）
  Future<Anime?> getAnimeDetail(String bangumiId) async {
    final cacheKey = 'detail_$bangumiId';
    
    // 1. 检查缓存
    if (_animeDetailCache.containsKey(cacheKey)) {
      final cached = _animeDetailCache[cacheKey]!;
      if (!cached.isExpired) {
        print('✓ 使用缓存的动画详情: $bangumiId');
        return cached.data;
      } else {
        _animeDetailCache.remove(cacheKey);
        print('✗ 详情缓存已过期: $bangumiId');
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
      // 请求完成后移除
      _pendingDetailRequests.remove(cacheKey);
    }
  }
  
  /// 实际执行获取详情的请求（带重试机制）
  Future<Anime?> _fetchAnimeDetail(String bangumiId, String cacheKey, {int retryCount = 0}) async {
    try {
      print('📖 从API获取动画详情: $bangumiId ${retryCount > 0 ? "(重试 $retryCount)" : ""}');
      final startTime = DateTime.now();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/v0/subjects/$bangumiId'),
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(_detailTimeout);
      
      if (response.statusCode == 200) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        print('✓ 获取详情成功，耗时: ${elapsed}ms');
        
        final data = json.decode(response.body);
        final anime = _parseAnime(data);
        
        if (anime != null) {
          // 缓存结果
          _animeDetailCache[cacheKey] = _CacheItem(anime, _detailCacheExpiry);
          print('✓ 动画详情已缓存: $bangumiId');
        }
        
        return anime;
      } else if (response.statusCode == 404) {
        print('✗ 动画不存在: $bangumiId');
        return null;
      } else if (response.statusCode == 429) {
        print('✗ API请求频率限制，请稍后再试');
        throw Exception('API请求频率限制');
      } else {
        print('✗ HTTP请求失败: ${response.statusCode}');
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // 网络错误，尝试重试
      if (retryCount < 2) {
        print('⚠️ 网络错误，准备重试: $e');
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        return _fetchAnimeDetail(bangumiId, cacheKey, retryCount: retryCount + 1);
      }
      print('✗ 获取动画详情失败（已重试$retryCount次）: $e');
      rethrow;
    } catch (e) {
      // 超时或其他错误，尝试重试一次
      if (retryCount < 1 && e.toString().contains('TimeoutException')) {
        print('⚠️ 请求超时，准备重试: $e');
        await Future.delayed(const Duration(milliseconds: 300));
        return _fetchAnimeDetail(bangumiId, cacheKey, retryCount: retryCount + 1);
      }
      print('✗ 获取动画详情失败: $e');
      rethrow;
    }
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
      final rank = item['rating']?['rank'] ?? item['rank']; // 提取排名
      final airDate = item['air_date'] ?? item['date'] ?? '';
      final eps = item['eps'] ?? item['total_episodes'] ?? 0;
      final year = _extractYear(airDate);
      
      // 提取标签（加载全部标签）
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
        videoUrl: '', // Bangumi不提供视频链接
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
  
  /// 提取年份
  int _extractYear(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().year;
    
    final regex = RegExp(r'(\d{4})');
    final match = regex.firstMatch(dateStr);
    return int.tryParse(match?.group(1) ?? '') ?? DateTime.now().year;
  }
  
  /// 提取年月信息（格式化为 "2025年1月"）
  String _extractYearMonth(String dateStr) {
    if (dateStr.isEmpty) return '';
    
    final date = DateTime.tryParse(dateStr);
    if (date != null) {
      return '${date.year}年${date.month}月';
    }
    
    // 尝试匹配 YYYY-MM 格式
    final regex = RegExp(r'(\d{4})-(\d{1,2})');
    final match = regex.firstMatch(dateStr);
    if (match != null) {
      final year = match.group(1);
      final month = match.group(2);
      return '$year年$month月';
    }
    
    return '';
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
  static Map<String, dynamic> getCacheStats() {
    return {
      'listCache': _animeListCache.length,
      'detailCache': _animeDetailCache.length,
      'totalCacheItems': _animeListCache.length + _animeDetailCache.length,
      'pendingListRequests': _pendingListRequests.length,
      'pendingDetailRequests': _pendingDetailRequests.length,
    };
  }
  
  /// 清理所有缓存
  static void clearCache() {
    final listCacheCount = _animeListCache.length;
    final detailCacheCount = _animeDetailCache.length;
    
    _animeListCache.clear();
    _animeDetailCache.clear();
    
    print('BangumiApiService: 清理缓存 - ${listCacheCount}个列表缓存，${detailCacheCount}个详情缓存');
  }
  
  /// 清理所有待处理的请求
  static void clearPendingRequests() {
    _pendingListRequests.clear();
    _pendingDetailRequests.clear();
    print('所有待处理的请求已清理');
  }
}
