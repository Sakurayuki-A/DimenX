import '../models/anime.dart';
import 'bangumi_api_service.dart';

/// 全局缓存管理器
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // 时间表缓存
  final Map<int, List<Anime>> _weeklyCalendar = {};
  final Set<int> _loadedWeekdays = {};

  /// 获取时间表缓存
  Map<int, List<Anime>> get weeklyCalendar => _weeklyCalendar;
  Set<int> get loadedWeekdays => _loadedWeekdays;

  /// 检查是否已缓存
  bool isWeekdayCached(int weekday) {
    return _loadedWeekdays.contains(weekday) && _weeklyCalendar.containsKey(weekday);
  }

  /// 获取缓存的星期数据
  List<Anime>? getCachedWeekday(int weekday) {
    if (isWeekdayCached(weekday)) {
      return _weeklyCalendar[weekday];
    }
    return null;
  }

  /// 缓存星期数据
  void cacheWeekday(int weekday, List<Anime> animeList) {
    _weeklyCalendar[weekday] = animeList;
    _loadedWeekdays.add(weekday);
    print('CacheManager: 缓存星期$weekday 数据，共${animeList.length}个番剧');
  }

  /// 移除特定星期的缓存
  void removeCachedWeekday(int weekday) {
    _weeklyCalendar.remove(weekday);
    _loadedWeekdays.remove(weekday);
    print('CacheManager: 移除星期$weekday 缓存');
  }

  /// 清理所有缓存（包括时间表和Bangumi API缓存）
  void clearAllCache() {
    final totalCached = _loadedWeekdays.length;
    _weeklyCalendar.clear();
    _loadedWeekdays.clear();
    
    // 清理Bangumi API缓存
    BangumiApiService.clearCache();
    
    print('CacheManager: 清理所有缓存，共清理${totalCached}个星期的数据和Bangumi API缓存');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    final totalAnime = _weeklyCalendar.values
        .expand((list) => list)
        .length;
    
    final bangumiCacheStats = BangumiApiService.getCacheStats();
    
    return {
      'cachedWeekdays': _loadedWeekdays.length,
      'totalAnime': totalAnime,
      'weekdays': _loadedWeekdays.toList()..sort(),
      'bangumiListCache': bangumiCacheStats['listCache'],
      'bangumiDetailCache': bangumiCacheStats['detailCache'],
    };
  }

  /// 打印缓存状态
  void printCacheStatus() {
    final stats = getCacheStats();
    print('CacheManager: 缓存状态 - ${stats['cachedWeekdays']}个星期，${stats['totalAnime']}个番剧');
    print('CacheManager: 已缓存星期: ${stats['weekdays']}');
    print('CacheManager: Bangumi列表缓存: ${stats['bangumiListCache']}项');
    print('CacheManager: Bangumi详情缓存: ${stats['bangumiDetailCache']}项');
  }
}
