/// 标题归一化器 - 单一职责：标题清洗和归一化
class TitleNormalizer {
  /// 归一化标题（用于去重）
  String normalize(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_·・]+'), '')
        .replaceAll(RegExp(r'[【】\[\]（）()]'), '')
        .replaceAll(RegExp(r'[!！?？。，,、]'), '')
        .trim();
  }

  /// 清洗标题（移除无关信息）
  String clean(String title) {
    String cleaned = title;

    // 移除常见的无关信息
    final removePatterns = [
      r'【.*?】',
      r'\[.*?\]',
      r'（.*?）',
      r'\(.*?\)',
      r'更新至\d+集',
      r'全\d+集',
      r'共\d+集',
      r'第\d+集',
      r'HD',
      r'BD',
      r'1080P',
      r'720P',
    ];

    for (final pattern in removePatterns) {
      cleaned = cleaned.replaceAll(RegExp(pattern), '');
    }

    return cleaned.trim();
  }
}
