import 'bangumi_api_service.dart';
import 'bangumi_api_service_fast.dart';

/// Bangumi API 性能对比测试
class BangumiApiBenchmark {
  /// 对比测试：获取热门动画
  static Future<void> benchmarkGetHotAnime({int limit = 20}) async {
    print('\n========== 性能对比：获取热门动画 ==========\n');
    
    // 清理缓存，确保公平对比
    BangumiApiService.clearAllCache();
    BangumiApiServiceFast.clearAllCache();
    
    // 测试原版 API
    print('【测试 1】原版 BangumiApiService:');
    final startTime1 = DateTime.now();
    try {
      final service1 = BangumiApiService();
      final results1 = await service1.getHotAnime(limit: limit);
      final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;
      print('✓ 成功获取 ${results1.length} 个结果');
      print('⏱️  耗时: ${elapsed1}ms\n');
    } catch (e) {
      final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;
      print('✗ 失败: $e');
      print('⏱️  耗时: ${elapsed1}ms\n');
    }
    
    // 等待一下，避免请求过快
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 测试优化版 API
    print('【测试 2】优化版 BangumiApiServiceFast:');
    final startTime2 = DateTime.now();
    try {
      final results2 = await BangumiApiServiceFast.getHotAnime(limit: limit);
      final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;
      print('✓ 成功获取 ${results2.length} 个结果');
      print('⏱️  耗时: ${elapsed2}ms\n');
    } catch (e) {
      final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;
      print('✗ 失败: $e');
      print('⏱️  耗时: ${elapsed2}ms\n');
    }
    
    print('========================================\n');
  }
  
  /// 对比测试：搜索动画
  static Future<void> benchmarkSearchAnime(String keyword, {int limit = 20}) async {
    print('\n========== 性能对比：搜索动画 "$keyword" ==========\n');
    
    // 清理缓存
    BangumiApiService.clearAllCache();
    BangumiApiServiceFast.clearAllCache();
    
    // 测试原版 API
    print('【测试 1】原版 BangumiApiService:');
    final startTime1 = DateTime.now();
    try {
      final service1 = BangumiApiService();
      final results1 = await service1.searchAnime(keyword, limit: limit);
      final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;
      print('✓ 成功获取 ${results1.length} 个结果');
      print('⏱️  耗时: ${elapsed1}ms\n');
    } catch (e) {
      final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;
      print('✗ 失败: $e');
      print('⏱️  耗时: ${elapsed1}ms\n');
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 测试优化版 API
    print('【测试 2】优化版 BangumiApiServiceFast:');
    final startTime2 = DateTime.now();
    try {
      final results2 = await BangumiApiServiceFast.searchAnime(keyword, limit: limit);
      final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;
      print('✓ 成功获取 ${results2.length} 个结果');
      print('⏱️  耗时: ${elapsed2}ms\n');
    } catch (e) {
      final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;
      print('✗ 失败: $e');
      print('⏱️  耗时: ${elapsed2}ms\n');
    }
    
    print('========================================\n');
  }
  
  /// 对比测试：获取动画详情
  static Future<void> benchmarkGetAnimeDetail(String bangumiId) async {
    print('\n========== 性能对比：获取动画详情 $bangumiId ==========\n');
    
    // 清理缓存
    BangumiApiService.clearAllCache();
    BangumiApiServiceFast.clearAllCache();
    
    // 测试原版 API
    print('【测试 1】原版 BangumiApiService:');
    final startTime1 = DateTime.now();
    try {
      final service1 = BangumiApiService();
      final result1 = await service1.getAnimeDetail(bangumiId);
      final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;
      if (result1 != null) {
        print('✓ 成功获取详情: ${result1.title}');
      } else {
        print('✗ 未找到动画');
      }
      print('⏱️  耗时: ${elapsed1}ms\n');
    } catch (e) {
      final elapsed1 = DateTime.now().difference(startTime1).inMilliseconds;
      print('✗ 失败: $e');
      print('⏱️  耗时: ${elapsed1}ms\n');
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 测试优化版 API
    print('【测试 2】优化版 BangumiApiServiceFast:');
    final startTime2 = DateTime.now();
    try {
      final result2 = await BangumiApiServiceFast.getAnimeDetail(bangumiId);
      final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;
      if (result2 != null) {
        print('✓ 成功获取详情: ${result2.title}');
      } else {
        print('✗ 未找到动画');
      }
      print('⏱️  耗时: ${elapsed2}ms\n');
    } catch (e) {
      final elapsed2 = DateTime.now().difference(startTime2).inMilliseconds;
      print('✗ 失败: $e');
      print('⏱️  耗时: ${elapsed2}ms\n');
    }
    
    print('========================================\n');
  }
  
  /// 完整性能测试套件
  static Future<void> runFullBenchmark() async {
    print('\n');
    print('╔════════════════════════════════════════════════════════╗');
    print('║     Bangumi API 性能对比测试                           ║');
    print('╚════════════════════════════════════════════════════════╝');
    print('\n');
    
    // 测试 1: 获取热门动画
    await benchmarkGetHotAnime(limit: 20);
    
    // 测试 2: 搜索动画
    await benchmarkSearchAnime('命运石之门', limit: 20);
    
    // 测试 3: 获取动画详情
    await benchmarkGetAnimeDetail('9253'); // 命运石之门的 ID
    
    // 显示缓存统计
    print('\n========== 缓存统计 ==========\n');
    print('原版 API 缓存: ${BangumiApiService.getCacheStats()}');
    print('优化版 API 缓存: ${BangumiApiServiceFast.getCacheStats()}');
    print('\n==============================\n');
    
    // 清理资源
    BangumiApiServiceFast.dispose();
  }
}
