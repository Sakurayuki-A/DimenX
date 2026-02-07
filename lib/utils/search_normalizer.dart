/// 搜索关键词标准化工具
/// 用于提高视频源搜索的匹配率
class SearchNormalizer {
  /// 标准化搜索关键词
  /// 
  /// 处理以下问题：
  /// 1. 数字转换（第2季 ↔ 第二季）
  /// 2. 空格和标点符号
  /// 3. 全角半角转换
  /// 4. 常见别名和缩写
  static String normalize(String query) {
    if (query.isEmpty) return query;
    
    String normalized = query;
    
    // 1. 转换为小写（保留中文）
    normalized = normalized.toLowerCase();
    
    // 2. 移除多余空格
    normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // 3. 全角转半角
    normalized = _convertFullWidthToHalfWidth(normalized);
    
    // 4. 移除特殊标点符号
    normalized = _removeSpecialPunctuation(normalized);
    
    // 5. 标准化季数表达
    normalized = _normalizeSeasonExpression(normalized);
    
    return normalized;
  }
  
  /// 生成多个搜索变体
  /// 返回多个可能的搜索关键词，提高匹配率
  static List<String> generateVariants(String query) {
    if (query.isEmpty) return [query];
    
    final variants = <String>{};
    final normalized = normalize(query);
    
    // 1. 原始标准化版本
    variants.add(normalized);
    
    // 2. 移除所有空格的版本
    variants.add(normalized.replaceAll(' ', ''));
    
    // 3. 数字和中文数字的变体
    variants.addAll(_generateNumberVariants(normalized));
    
    // 4. 季数表达的变体
    variants.addAll(_generateSeasonVariants(normalized));
    
    // 5. 移除括号内容的版本
    final withoutBrackets = _removeBracketContent(normalized);
    if (withoutBrackets != normalized) {
      variants.add(withoutBrackets);
      variants.add(withoutBrackets.replaceAll(' ', ''));
    }
    
    // 6. 只保留主标题（移除副标题）
    final mainTitle = _extractMainTitle(normalized);
    if (mainTitle != normalized) {
      variants.add(mainTitle);
      variants.add(mainTitle.replaceAll(' ', ''));
    }
    
    return variants.toList();
  }
  
  /// 全角转半角
  static String _convertFullWidthToHalfWidth(String text) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      
      // 全角空格
      if (char == 0x3000) {
        buffer.write(' ');
      }
      // 全角字符（！-～）
      else if (char >= 0xFF01 && char <= 0xFF5E) {
        buffer.writeCharCode(char - 0xFEE0);
      }
      // 其他字符保持不变
      else {
        buffer.write(text[i]);
      }
    }
    
    return buffer.toString();
  }
  
  /// 移除特殊标点符号
  static String _removeSpecialPunctuation(String text) {
    // 保留：空格、数字、字母、中文、日文、韩文
    // 移除：其他标点符号
    return text.replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af]'), ' ')
               .replaceAll(RegExp(r'\s+'), ' ')
               .trim();
  }
  
  /// 标准化季数表达
  static String _normalizeSeasonExpression(String text) {
    String result = text;
    
    // 第X季 → 第X季（统一格式）
    result = result.replaceAllMapped(
      RegExp(r'第\s*([0-9一二三四五六七八九十]+)\s*季'),
      (match) => '第${match.group(1)}季',
    );
    
    // Season X → 第X季
    result = result.replaceAllMapped(
      RegExp(r'season\s*([0-9]+)', caseSensitive: false),
      (match) => '第${match.group(1)}季',
    );
    
    // SX → 第X季
    result = result.replaceAllMapped(
      RegExp(r'\bs([0-9]+)\b', caseSensitive: false),
      (match) => '第${match.group(1)}季',
    );
    
    return result;
  }
  
  /// 生成数字变体（阿拉伯数字 ↔ 中文数字）
  static List<String> _generateNumberVariants(String text) {
    final variants = <String>{};
    
    // 阿拉伯数字 → 中文数字
    String arabicToChinese = text;
    arabicToChinese = arabicToChinese.replaceAllMapped(
      RegExp(r'第([0-9]+)季'),
      (match) {
        final num = int.tryParse(match.group(1)!);
        if (num != null && num <= 10) {
          return '第${_numberToChinese(num)}季';
        }
        return match.group(0)!;
      },
    );
    if (arabicToChinese != text) {
      variants.add(arabicToChinese);
    }
    
    // 中文数字 → 阿拉伯数字
    String chineseToArabic = text;
    chineseToArabic = chineseToArabic.replaceAllMapped(
      RegExp(r'第([一二三四五六七八九十]+)季'),
      (match) {
        final num = _chineseToNumber(match.group(1)!);
        if (num != null) {
          return '第${num}季';
        }
        return match.group(0)!;
      },
    );
    if (chineseToArabic != text) {
      variants.add(chineseToArabic);
    }
    
    return variants.toList();
  }
  
  /// 生成季数表达的变体
  static List<String> _generateSeasonVariants(String text) {
    final variants = <String>{};
    
    // 第X季 → Season X
    String toSeason = text.replaceAllMapped(
      RegExp(r'第([0-9]+)季'),
      (match) => 'season${match.group(1)}',
    );
    if (toSeason != text) {
      variants.add(toSeason);
      variants.add(toSeason.replaceAll('season', 'Season '));
    }
    
    // 第X季 → SX
    String toS = text.replaceAllMapped(
      RegExp(r'第([0-9]+)季'),
      (match) => 's${match.group(1)}',
    );
    if (toS != text) {
      variants.add(toS);
      variants.add(toS.toUpperCase());
    }
    
    // 移除季数表达
    String withoutSeason = text.replaceAll(RegExp(r'第[0-9一二三四五六七八九十]+季'), '').trim();
    if (withoutSeason != text && withoutSeason.isNotEmpty) {
      variants.add(withoutSeason);
    }
    
    return variants.toList();
  }
  
  /// 移除括号内容
  static String _removeBracketContent(String text) {
    return text
        .replaceAll(RegExp(r'\([^)]*\)'), '') // 圆括号
        .replaceAll(RegExp(r'\[[^\]]*\]'), '') // 方括号
        .replaceAll(RegExp(r'【[^】]*】'), '') // 中文方括号
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  
  /// 提取主标题（移除副标题）
  static String _extractMainTitle(String text) {
    // 常见的副标题分隔符
    final separators = [':', '：', '-', '~', '～', '|', '｜'];
    
    for (final sep in separators) {
      if (text.contains(sep)) {
        final parts = text.split(sep);
        if (parts.isNotEmpty) {
          return parts[0].trim();
        }
      }
    }
    
    return text;
  }
  
  /// 阿拉伯数字转中文数字
  static String _numberToChinese(int num) {
    const chinese = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    
    if (num >= 0 && num <= 10) {
      return chinese[num];
    } else if (num > 10 && num < 20) {
      return '十${chinese[num - 10]}';
    } else if (num >= 20 && num < 100) {
      final tens = num ~/ 10;
      final ones = num % 10;
      if (ones == 0) {
        return '${chinese[tens]}十';
      } else {
        return '${chinese[tens]}十${chinese[ones]}';
      }
    }
    
    return num.toString();
  }
  
  /// 中文数字转阿拉伯数字
  static int? _chineseToNumber(String chinese) {
    const map = {
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '十': 10,
    };
    
    // 单个字符
    if (chinese.length == 1) {
      return map[chinese];
    }
    
    // 十X（11-19）
    if (chinese.startsWith('十') && chinese.length == 2) {
      final ones = map[chinese[1]];
      if (ones != null) {
        return 10 + ones;
      }
    }
    
    // X十（20, 30, ...）
    if (chinese.endsWith('十') && chinese.length == 2) {
      final tens = map[chinese[0]];
      if (tens != null) {
        return tens * 10;
      }
    }
    
    // X十Y（21-99）
    if (chinese.length == 3 && chinese[1] == '十') {
      final tens = map[chinese[0]];
      final ones = map[chinese[2]];
      if (tens != null && ones != null) {
        return tens * 10 + ones;
      }
    }
    
    return null;
  }
  
  /// 计算两个字符串的相似度（0-1之间）
  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    
    if (longer.length == 0) return 1.0;
    
    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length;
  }
  
  /// 计算编辑距离（Levenshtein Distance）
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    
    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );
    
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // 删除
          matrix[i][j - 1] + 1,      // 插入
          matrix[i - 1][j - 1] + cost, // 替换
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[len1][len2];
  }
}
