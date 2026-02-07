import 'search_config.dart';
import 'search_logger.dart';

/// 标题验证器 - 单一职责：验证标题有效性
class TitleValidator {
  final SearchLogger logger;

  const TitleValidator({required this.logger});

  /// 验证标题是否有效
  bool isValid(String title) {
    if (title.isEmpty) {
      logger.filter('标题为空');
      return false;
    }

    // 长度检查
    if (!_isValidLength(title)) {
      logger.filter('标题长度无效: ${title.length}');
      return false;
    }

    // 字符类型检查
    if (!_hasValidCharacters(title)) {
      logger.filter('标题字符类型无效');
      return false;
    }

    // 黑名单检查
    if (_isBlacklisted(title)) {
      return false;
    }

    // 特殊字符检查
    if (_hasTooManySpecialChars(title)) {
      logger.filter('特殊字符过多');
      return false;
    }

    // 纯数字检查
    if (_isPureNumber(title)) {
      logger.filter('纯数字标题');
      return false;
    }

    return true;
  }

  bool _isValidLength(String title) {
    return title.length >= SearchConfig.minTitleLength &&
        title.length <= SearchConfig.maxTitleLength;
  }

  bool _hasValidCharacters(String title) {
    return RegExp(r'[\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FFa-zA-Z]')
        .hasMatch(title);
  }

  bool _isBlacklisted(String title) {
    final lower = title.toLowerCase();
    
    for (final keyword in SearchConfig.titleBlacklist) {
      final keywordLower = keyword.toLowerCase();
      
      // 精确匹配或包含检查
      if (lower == keywordLower || lower.contains(keywordLower)) {
        logger.filter('黑名单关键词: "$keyword"');
        return true;
      }
    }
    
    return false;
  }

  bool _hasTooManySpecialChars(String title) {
    final specialCount = RegExp(r'[^\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FFa-zA-Z0-9\s]')
        .allMatches(title)
        .length;
    return specialCount > title.length * SearchConfig.maxSpecialCharRatio;
  }

  bool _isPureNumber(String title) {
    return RegExp(r'^\d+$').hasMatch(title.trim());
  }
}
