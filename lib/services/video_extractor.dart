// 兼容层：导出新的模块化实现
// 保持向后兼容，所有旧代码无需修改

export 'video_extraction/video_extractor_v2.dart';

// 为了完全兼容，创建别名
import 'video_extraction/video_extractor_v2.dart' as v2;

/// 视频提取器（兼容旧版本API）
class VideoExtractor {
  static final VideoExtractor _instance = VideoExtractor._internal();
  factory VideoExtractor() => _instance;
  VideoExtractor._internal();

  final v2.VideoExtractorV2 _extractor = v2.VideoExtractorV2();

  /// 提取视频链接（默认启用日志）
  Future<v2.VideoExtractResult> extractVideoUrl(
    String episodeUrl, 
    dynamic rule, {
    bool enableLogging = true,
    bool verboseLogging = false,
  }) async {
    return await _extractor.extractVideoUrl(
      episodeUrl, 
      rule,
      enableLogging: enableLogging,
      verboseLogging: verboseLogging,
    );
  }

  /// 停止提取
  Future<void> stopExtraction() async {
    return await _extractor.stopExtraction();
  }
}

// 导出结果类型别名
typedef VideoExtractResult = v2.VideoExtractResult;

