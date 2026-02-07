import 'search_config.dart';

/// 系列作品检测器 - 单一职责：检测和分类系列作品
class SeriesDetector {
  /// 提取系列信息
  Map<String, String> extractSeriesInfo(String title) {
    final result = <String, String>{};
    String baseTitle = title;

    // 检测季度
    final season = _detectSeason(title);
    if (season != null) {
      result['season'] = season;
      baseTitle = _removeSeasonInfo(title);
    }

    // 检测特殊版本
    final version = _detectSpecialVersion(title);
    if (version != null) {
      result['version'] = version;
      baseTitle = _removeVersionInfo(title, version);
    }

    result['baseTitle'] = baseTitle.trim();
    return result;
  }

  /// 获取系列优先级（数字越小优先级越高）
  int getPriority(String title) {
    final lower = title.toLowerCase();

    // 本篇优先级最高
    if (!_hasSeason(lower) && !_hasSpecialVersion(lower)) {
      return 0;
    }

    // 第一季
    if (lower.contains('第一季') || lower.contains('season 1') || lower.contains('s1')) {
      return 1;
    }

    // 第二季
    if (lower.contains('第二季') || lower.contains('season 2') || lower.contains('s2')) {
      return 2;
    }

    // 剧场版
    if (lower.contains('剧场版') || lower.contains('movie')) {
      return 10;
    }

    // OVA/SP
    if (lower.contains('ova') || lower.contains('sp')) {
      return 20;
    }

    return 100;
  }

  String? _detectSeason(String title) {
    for (final pattern in SearchConfig.seasonPatterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(title);
      if (match != null) {
        return match.group(1);
      }
    }
    return null;
  }

  String? _detectSpecialVersion(String title) {
    final lower = title.toLowerCase();
    for (final version in SearchConfig.specialVersions) {
      if (lower.contains(version.toLowerCase())) {
        return version;
      }
    }
    return null;
  }

  String _removeSeasonInfo(String title) {
    String result = title;
    for (final pattern in SearchConfig.seasonPatterns) {
      result = result.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }
    return result;
  }

  String _removeVersionInfo(String title, String version) {
    return title.replaceAll(RegExp(version, caseSensitive: false), '');
  }

  bool _hasSeason(String title) {
    return SearchConfig.seasonPatterns.any(
      (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(title),
    );
  }

  bool _hasSpecialVersion(String title) {
    return SearchConfig.specialVersions.any(
      (version) => title.contains(version.toLowerCase()),
    );
  }
}
