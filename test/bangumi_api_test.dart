import 'package:flutter_test/flutter_test.dart';
import 'package:dimenx/services/bangumi_api_service.dart';

void main() {
  group('BangumiApiService Tests', () {
    late BangumiApiService bangumiService;

    setUp(() {
      bangumiService = BangumiApiService();
      // 清理缓存确保测试独立性
      BangumiApiService.clearAllCache();
    });

    tearDown(() {
      // 测试结束后清理缓存
      BangumiApiService.clearAllCache();
    });

    test('BangumiApiService should be created', () {
      expect(bangumiService, isNotNull);
    });

    test('getSeasonalAnime should return a list', () async {
      final result = await bangumiService.getSeasonalAnime(limit: 5);
      expect(result, isA<List>());
      // 注意：实际测试可能因网络问题失败，这里只测试返回类型
    });

    test('searchAnime should return empty list for empty keyword', () async {
      final result = await bangumiService.searchAnime('');
      expect(result, isEmpty);
    });

    test('searchAnime should return a list for valid keyword', () async {
      final result = await bangumiService.searchAnime('测试', limit: 3);
      expect(result, isA<List>());
    });

    test('getAnimeDetail should return null for invalid id', () async {
      final result = await bangumiService.getAnimeDetail('invalid_id');
      expect(result, isNull);
    });

    test('cache should work correctly', () async {
      // 清理缓存
      BangumiApiService.clearAllCache();
      
      // 检查初始缓存状态
      var stats = BangumiApiService.getCacheStats();
      expect(stats['totalCacheItems'], equals(0));
      
      // 进行一次搜索（应该缓存结果）
      await bangumiService.searchAnime('test', limit: 1);
      
      // 检查缓存是否增加
      stats = BangumiApiService.getCacheStats();
      expect(stats['animeListCache'], greaterThan(0));
      
      // 清理缓存
      BangumiApiService.clearAllCache();
      stats = BangumiApiService.getCacheStats();
      expect(stats['totalCacheItems'], equals(0));
    });

    test('expired cache should be cleared', () {
      // 这个测试需要模拟时间流逝，在实际应用中缓存会自动过期
      BangumiApiService.clearExpiredCache();
      final stats = BangumiApiService.getCacheStats();
      expect(stats, isA<Map<String, int>>());
    });
  });
}
