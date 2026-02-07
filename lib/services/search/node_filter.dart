import 'package:html/dom.dart' as dom;
import 'search_config.dart';
import 'search_logger.dart';

/// 节点过滤器 - 单一职责：过滤无效节点
class NodeFilter {
  final SearchLogger logger;

  const NodeFilter({required this.logger});

  /// 过滤出有效的番剧卡片节点
  List<dom.Element> filterAnimeCards(List<dom.Element> nodes) {
    logger.info('开始过滤 ${nodes.length} 个节点');
    
    final filtered = <dom.Element>[];
    
    for (final node in nodes) {
      if (_isValidAnimeCard(node)) {
        filtered.add(node);
        logger.filter('保留: 有效番剧卡片');
      }
    }
    
    logger.success('过滤完成: ${filtered.length}/${nodes.length} 个有效节点');
    return filtered;
  }

  /// 判断是否为有效的番剧卡片
  bool _isValidAnimeCard(dom.Element node) {
    // 0. 检查是否为容器节点（包含多个子卡片）
    if (_isContainer(node)) {
      logger.filter('识别为容器节点，跳过过滤');
      return true; // 容器节点直接通过，后续会展开
    }

    // 1. 必须有链接
    if (!_hasValidLink(node)) {
      logger.filter('过滤: 无有效链接');
      return false;
    }

    // 2. 必须有图片或标题
    if (!_hasImageOrTitle(node)) {
      logger.filter('过滤: 无图片或标题');
      return false;
    }

    // 3. 黑名单检查（容器节点已在步骤0跳过）
    if (_isBlacklisted(node)) {
      return false;
    }

    // 4. 垃圾内容检查
    if (_hasGarbageContent(node)) {
      return false;
    }

    // 5. 文本长度检查（容器节点已在步骤0跳过）
    if (_isTooLong(node)) {
      logger.filter('过滤: 文本过长');
      return false;
    }

    return true;
  }
  
  /// 判断是否为容器节点（包含多个子卡片）
  /// 完全基于结构特征，不依赖 class 名称
  bool _isContainer(dom.Element node) {
    // 统计有多少个子元素包含链接
    final childrenWithLinks = node.children.where((child) {
      return child.querySelector('a[href]') != null;
    }).toList();
    
    // 如果有 3 个以上带链接的直接子元素，很可能是容器
    if (childrenWithLinks.length >= 3) {
      return true;
    }
    
    // 进一步检查：如果子元素不多，但孙元素很多（嵌套结构）
    final allLinks = node.querySelectorAll('a[href]');
    if (allLinks.length >= 3) {
      // 有很多链接，说明是容器
      // 额外检查：这些链接是否分布在不同的子树中
      final uniqueParents = <dom.Element>{};
      for (final link in allLinks) {
        var parent = link.parent;
        // 向上找3层，找到卡片级别的父节点
        for (int i = 0; i < 3 && parent != null && parent != node; i++) {
          parent = parent.parent;
        }
        if (parent != null && parent != node) {
          uniqueParents.add(parent);
        }
      }
      
      // 如果链接分布在2个以上不同的子树，说明是容器
      if (uniqueParents.length >= 2) {
        return true;
      }
    }
    
    return false;
  }

  bool _hasValidLink(dom.Element node) {
    final links = node.querySelectorAll('a[href]');
    for (final link in links) {
      final href = link.attributes['href'] ?? '';
      if (href.isNotEmpty && href != 'void(0)') {
        // 允许 javascript: 和 # 开头的链接（SPA 路由）
        // 只要不是空的 # 就行
        if (href.startsWith('javascript:')) {
          continue; // 跳过纯 javascript 链接
        }
        if (href == '#') {
          continue; // 跳过空锚点
        }
        return true;
      }
    }
    return false;
  }

  bool _hasImageOrTitle(dom.Element node) {
    final hasImage = node.querySelectorAll('img').isNotEmpty;
    final hasTitle = node.querySelectorAll('h1, h2, h3, h4, .title, .name, a[title]').isNotEmpty;
    return hasImage || hasTitle;
  }

  bool _isBlacklisted(dom.Element node) {
    final className = node.attributes['class']?.toLowerCase() ?? '';
    
    for (final keyword in SearchConfig.nodeClassBlacklist) {
      if (className.contains(keyword)) {
        logger.filter('过滤: 黑名单class "$keyword"');
        return true;
      }
    }
    
    return false;
  }

  bool _hasGarbageContent(dom.Element node) {
    final text = node.text.toLowerCase();
    
    for (final keyword in SearchConfig.garbageKeywords) {
      if (text.contains(keyword.toLowerCase())) {
        logger.filter('过滤: 垃圾内容 "$keyword"');
        return true;
      }
    }
    
    return false;
  }

  bool _isTooLong(dom.Element node) {
    return node.text.trim().length > SearchConfig.maxTextLength;
  }
}
