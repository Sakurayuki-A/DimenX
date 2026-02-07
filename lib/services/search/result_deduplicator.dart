import '../../models/anime.dart';
import 'title_normalizer.dart';
import 'series_detector.dart';
import 'search_logger.dart';

/// 结果去重器 - 单一职责：去重和合并系列作品
class ResultDeduplicator {
  final TitleNormalizer normalizer;
  final SeriesDetector seriesDetector;
  final SearchLogger logger;

  const ResultDeduplicator({
    required this.normalizer,
    required this.seriesDetector,
    required this.logger,
  });

  /// 去重并合并系列作品
  List<Anime> deduplicate(List<Anime> animes, {bool mergeSeries = false}) {
    if (animes.isEmpty) return animes;

    logger.info('开始去重，原始数量: ${animes.length}');

    if (!mergeSeries) {
      // 简单去重：只合并完全相同的标题
      return _simpleDedup(animes);
    }

    // 系列合并去重（原逻辑）
    final Map<String, List<Anime>> seriesMap = {};

    // 按基础标题分组
    for (final anime in animes) {
      final normalized = normalizer.normalize(anime.title);
      if (normalized.isEmpty) continue;

      final seriesInfo = seriesDetector.extractSeriesInfo(anime.title);
      final baseTitle = normalizer.normalize(seriesInfo['baseTitle'] ?? normalized);

      if (!seriesMap.containsKey(baseTitle)) {
        seriesMap[baseTitle] = [];
      }
      seriesMap[baseTitle]!.add(anime);
    }

    // 每个系列只保留优先级最高的
    final result = <Anime>[];
    for (final entry in seriesMap.entries) {
      final seriesList = entry.value;

      // 按优先级排序
      seriesList.sort((a, b) {
        final priorityA = seriesDetector.getPriority(a.title);
        final priorityB = seriesDetector.getPriority(b.title);
        
        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }
        
        // 优先级相同，选择信息更完整的
        return _compareCompleteness(b, a);
      });

      result.add(seriesList.first);

      if (seriesList.length > 1) {
        logger.debug('合并系列: ${entry.key} (${seriesList.length}个版本)');
      }
    }

    logger.success('去重完成: ${result.length}/${animes.length}');
    return result;
  }

  /// 简单去重：只合并完全相同的标题
  List<Anime> _simpleDedup(List<Anime> animes) {
    final Map<String, Anime> uniqueMap = {};

    for (final anime in animes) {
      final normalized = normalizer.normalize(anime.title);
      if (normalized.isEmpty) continue;

      // 如果已存在，选择信息更完整的
      if (uniqueMap.containsKey(normalized)) {
        final existing = uniqueMap[normalized]!;
        if (_compareCompleteness(anime, existing) > 0) {
          uniqueMap[normalized] = anime;
        }
      } else {
        uniqueMap[normalized] = anime;
      }
    }

    final result = uniqueMap.values.toList();
    logger.success('简单去重完成: ${result.length}/${animes.length}');
    return result;
  }

  int _compareCompleteness(Anime a, Anime b) {
    int scoreA = 0;
    int scoreB = 0;

    if (a.imageUrl.isNotEmpty) scoreA += 2;
    if (b.imageUrl.isNotEmpty) scoreB += 2;

    if (a.description.isNotEmpty) scoreA += 1;
    if (b.description.isNotEmpty) scoreB += 1;

    if (a.rating > 0) scoreA += 1;
    if (b.rating > 0) scoreB += 1;

    return scoreA.compareTo(scoreB);
  }
}
