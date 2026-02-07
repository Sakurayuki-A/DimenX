import 'package:html/dom.dart' as dom;
import 'search_logger.dart';

/// 标题提取器 - 单一职责：从节点提取标题
class TitleExtractor {
  final SearchLogger logger;

  const TitleExtractor({required this.logger});

  /// 从节点提取最佳标题
  String extractTitle(dom.Element node) {
    final candidates = <String>[];

    // 策略1: a 标签的 title 属性
    _extractFromLinkTitles(node, candidates);

    // 策略2: a 标签的文本内容
    _extractFromLinkTexts(node, candidates);

    // 策略3: img 标签的 alt 属性
    _extractFromImageAlts(node, candidates);

    // 策略4: 标题元素
    _extractFromHeadings(node, candidates);

    // 调试：输出候选标题
    if (candidates.isEmpty) {
      logger.warning('未找到任何标题候选');
      logger.debug('节点 HTML: ${node.outerHtml.substring(0, node.outerHtml.length > 200 ? 200 : node.outerHtml.length)}...');
    } else {
      logger.debug('找到 ${candidates.length} 个标题候选: ${candidates.take(3).join(", ")}');
    }

    // 选择最佳候选
    return _selectBestCandidate(candidates);
  }

  void _extractFromLinkTitles(dom.Element node, List<String> candidates) {
    final links = node.querySelectorAll('a[title]');
    for (final link in links) {
      final title = link.attributes['title'] ?? '';
      if (title.isNotEmpty) {
        candidates.add(title);
      }
    }
  }

  void _extractFromLinkTexts(dom.Element node, List<String> candidates) {
    final links = node.querySelectorAll('a');
    for (final link in links) {
      final text = link.text.trim();
      if (text.isNotEmpty) {
        candidates.add(text);
      }
    }
  }

  void _extractFromImageAlts(dom.Element node, List<String> candidates) {
    final images = node.querySelectorAll('img[alt]');
    for (final img in images) {
      final alt = img.attributes['alt'] ?? '';
      if (alt.isNotEmpty) {
        candidates.add(alt);
      }
    }
  }

  void _extractFromHeadings(dom.Element node, List<String> candidates) {
    final headings = node.querySelectorAll('h1, h2, h3, h4, .title, .name');
    for (final heading in headings) {
      final text = heading.text.trim();
      if (text.isNotEmpty) {
        candidates.add(text);
      }
    }
  }

  String _selectBestCandidate(List<String> candidates) {
    if (candidates.isEmpty) return '';

    // 过滤明显的垃圾候选
    final filtered = candidates.where((text) {
      // 过滤按钮文本
      if (text.contains('点击') || text.contains('播放') || 
          text.contains('观看') || text.contains('立即')) {
        return false;
      }
      
      // 过滤集数标记
      if (RegExp(r'^第\d+集').hasMatch(text) || 
          text.contains('完结') && text.length < 10) {
        return false;
      }
      
      // 过滤纯数字或纯符号
      if (RegExp(r'^[\d\s\-_]+$').hasMatch(text)) {
        return false;
      }
      
      return true;
    }).toList();

    if (filtered.isEmpty) return '';

    // 按长度和质量排序，选择最合适的
    filtered.sort((a, b) {
      final scoreA = _scoreCandidate(a);
      final scoreB = _scoreCandidate(b);
      return scoreB.compareTo(scoreA);
    });

    return filtered.first;
  }

  int _scoreCandidate(String text) {
    int score = 0;

    // 长度适中加分（标题通常 4-30 字符）
    if (text.length >= 4 && text.length <= 30) {
      score += 30;
    } else if (text.length >= 2 && text.length <= 50) {
      score += 10;
    }

    // 包含中文/日文加分
    if (RegExp(r'[\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FF]').hasMatch(text)) {
      score += 30;
    }

    // 包含英文加分
    if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
      score += 15;
    }

    // 特殊字符过多减分
    final specialCount = RegExp(r'[^\u4e00-\u9fa5\u3040-\u309F\u30A0-\u30FFa-zA-Z0-9\s]')
        .allMatches(text)
        .length;
    if (specialCount > text.length * 0.3) score -= 20;
    
    // 包含"第X季"、"Season"等续集标记，略微加分（说明是正式标题）
    if (RegExp(r'第.季|Season|season|S\d+').hasMatch(text)) {
      score += 5;
    }

    return score;
  }
}
