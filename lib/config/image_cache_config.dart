import 'package:flutter/material.dart';

/// 图片缓存配置
class ImageCacheConfig {
  /// 初始化图片缓存
  static void init() {
    // 设置图片缓存大小
    PaintingBinding.instance.imageCache.maximumSize = 200; // 最多缓存200张图片
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 最多100MB
    
    print('✓ 图片缓存已初始化');
    print('  - 最大缓存数量: 200张');
    print('  - 最大缓存大小: 100MB');
  }
  
  /// 清理图片缓存
  static void clearCache() {
    // 清理内存缓存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    print('✓ 图片缓存已清理');
  }
  
  /// 获取缓存统计
  static Map<String, dynamic> getCacheStats() {
    final imageCache = PaintingBinding.instance.imageCache;
    return {
      'currentSize': imageCache.currentSize,
      'currentSizeBytes': imageCache.currentSizeBytes,
      'maximumSize': imageCache.maximumSize,
      'maximumSizeBytes': imageCache.maximumSizeBytes,
      'liveImageCount': imageCache.liveImageCount,
      'pendingImageCount': imageCache.pendingImageCount,
    };
  }
  
  /// 预加载图片
  static Future<void> precacheImages(BuildContext context, List<String> imageUrls) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(
            NetworkImage(url),
            context,
          );
        } catch (e) {
          print('预加载图片失败: $url, 错误: $e');
        }
      }
    }
  }
}
