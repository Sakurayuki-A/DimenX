import '../models/anime.dart';
import '../models/source_rule.dart';
import 'search/anime_search_service_v2.dart';

/// 兼容层：保持原有 API 接口，内部使用重构后的 V2 服务
/// 
/// 这个类作为向后兼容的包装器，确保现有代码无需修改即可使用新的搜索服务
class AnimeSearchService {
  final AnimeSearchServiceV2 _v2Service;

  /// 构造函数 - 保持与原版本相同的签名
  AnimeSearchService({
    bool enableLogging = true,
    bool verboseLogging = true, // 默认启用详细日志以便调试
  }) : _v2Service = AnimeSearchServiceV2(
          enableLogging: enableLogging,
          verboseLogging: verboseLogging,
        );

  /// 搜索动漫 - 保持与原版本相同的方法签名
  Future<List<Anime>> searchAnimes(
    String keyword,
    List<SourceRule> rules,
  ) async {
    return _v2Service.searchAnimes(keyword, rules);
  }
}
