import 'package:html/dom.dart' as dom;
import 'search_logger.dart';

/// 节点选择器 - 单一职责：CSS 选择器 + 手动索引过滤
class NodeSelector {
  final SearchLogger logger;

  const NodeSelector({required this.logger});

  /// 使用选择器获取节点
  List<dom.Element> selectNodes(dom.Document document, String selector) {
    try {
      List<dom.Element> nodes;
      
      // 如果是 XPath，尝试转换并处理
      if (selector.startsWith('//') || selector.startsWith('/')) {
        nodes = _selectByXPath(document, selector);
      } else {
        // 否则当作 CSS 选择器
        nodes = document.querySelectorAll(selector);
        logger.info('CSS 选择器找到 ${nodes.length} 个节点');
      }
      
      // 如果没找到节点，尝试降级策略
      if (nodes.isEmpty) {
        logger.warning('选择器未匹配任何节点，尝试降级策略');
        nodes = _fallbackSelection(document);
      }
      
      return nodes;
    } catch (e) {
      logger.error('选择器解析失败: $selector, 错误: $e');
      
      // 降级策略：尝试使用通用选择器
      return _fallbackSelection(document);
    }
  }
  
  /// 使用 XPath 选择节点（简化实现）
  List<dom.Element> _selectByXPath(dom.Document document, String xpath) {
    logger.debug('处理 XPath: $xpath');
    
    // 特殊处理：属性选择器 //*[@id="value"] 或 //tag[@attr="value"]
    if (xpath.contains('[@')) {
      return _selectByXPathWithAttribute(document, xpath);
    }
    
    // 解析 XPath 路径
    final steps = _parseXPath(xpath);
    logger.debug('XPath 步骤: ${steps.map((s) => '${s.tag}[${s.index}]${s.recursive ? " (递归)" : ""}').join(' > ')}');
    
    // 从根节点开始遍历
    List<dom.Element> currentNodes = [document.documentElement!];
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final nextNodes = <dom.Element>[];
      
      for (final node in currentNodes) {
        List<dom.Element> candidates;
        
        // 根据是否递归选择子节点
        if (step.recursive) {
          // 递归查找所有匹配的标签
          candidates = node.querySelectorAll(step.tag);
        } else {
          // 只查找直接子节点
          candidates = node.children
              .where((e) => e.localName == step.tag)
              .toList();
        }
        
        logger.debug('步骤 $i (${step.tag}): 找到 ${candidates.length} 个候选节点');
        
        // 应用索引过滤
        if (step.index > 0) {
          // 选择特定索引的节点
          if (step.index <= candidates.length) {
            nextNodes.add(candidates[step.index - 1]);
            logger.debug('  -> 选择索引 ${step.index}: ${candidates[step.index - 1].localName}');
          } else {
            logger.debug('  -> 索引 ${step.index} 超出范围 (最大: ${candidates.length})');
          }
        } else {
          // 选择所有节点
          nextNodes.addAll(candidates);
          logger.debug('  -> 选择所有 ${candidates.length} 个节点');
        }
      }
      
      currentNodes = nextNodes;
      logger.debug('当前节点数: ${currentNodes.length}');
      
      if (currentNodes.isEmpty) {
        logger.warning('在步骤 $i 后没有节点，提前终止');
        break;
      }
    }
    
    logger.info('XPath 匹配: ${currentNodes.length} 个节点');
    return currentNodes;
  }
  
  /// 处理带属性选择器的 XPath
  /// 例如: //*[@id="线路一"], //div[@class="item"], //a[@href]
  List<dom.Element> _selectByXPathWithAttribute(dom.Document document, String xpath) {
    logger.debug('处理属性选择器 XPath: $xpath');
    
    try {
      // 解析 XPath: //*[@id="value"] 或 //tag[@attr="value"]
      final match = RegExp(r'^//(\*|\w+)\[@(\w+)(?:="([^"]*)")?\]').firstMatch(xpath);
      
      if (match == null) {
        logger.warning('无法解析属性选择器: $xpath');
        return [];
      }
      
      final tag = match.group(1)!; // * 或具体标签名
      final attr = match.group(2)!; // 属性名
      final value = match.group(3); // 属性值（可能为空）
      
      logger.debug('解析结果: tag=$tag, attr=$attr, value=$value');
      
      // 转换为 CSS 选择器
      String cssSelector;
      if (tag == '*') {
        // 任意标签
        if (value != null) {
          cssSelector = '[$attr="$value"]';
        } else {
          cssSelector = '[$attr]';
        }
      } else {
        // 具体标签
        if (value != null) {
          cssSelector = '$tag[$attr="$value"]';
        } else {
          cssSelector = '$tag[$attr]';
        }
      }
      
      logger.debug('转换为 CSS: $cssSelector');
      
      final nodes = document.querySelectorAll(cssSelector);
      logger.info('属性选择器匹配: ${nodes.length} 个节点');
      
      return nodes;
    } catch (e) {
      logger.error('XPath选择器执行失败: $xpath, 错误: $e');
      return [];
    }
  }
  
  /// 解析 XPath 为步骤列表
  List<_XPathStep> _parseXPath(String xpath) {
    final steps = <_XPathStep>[];
    
    // 移除开头的 / 或 //
    bool startsWithDoubleSlash = xpath.startsWith('//');
    String path = xpath.replaceFirst(RegExp(r'^//|^/'), '');
    
    // 分割路径，但要注意 // 的情况
    final parts = <String>[];
    final segments = path.split('/');
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i].trim();
      if (segment.isEmpty) {
        // 遇到空段，说明有 //，下一个段应该是递归的
        if (i + 1 < segments.length) {
          parts.add('//' + segments[i + 1]);
          i++; // 跳过下一个
        }
      } else {
        parts.add(segment);
      }
    }
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;
      
      // 检查是否以 // 开头（递归）
      bool recursive = part.startsWith('//');
      String cleanPart = recursive ? part.substring(2) : part;
      
      // 解析标签和索引 例如: div[5]
      final match = RegExp(r'^(\w+)(?:\[(\d+)\])?').firstMatch(cleanPart);
      if (match != null) {
        final tag = match.group(1)!;
        final indexStr = match.group(2);
        final index = indexStr != null ? int.parse(indexStr) : 0;
        
        // 第一个步骤如果原 XPath 是 // 开头，则递归查找
        final isRecursive = (i == 0 && startsWithDoubleSlash) || recursive;
        
        steps.add(_XPathStep(
          tag: tag,
          index: index,
          recursive: isRecursive,
        ));
      }
    }
    
    return steps;
  }
  
  /// 降级选择策略：使用通用的动漫卡片选择器
  List<dom.Element> _fallbackSelection(dom.Document document) {
    logger.info('🔄 使用降级选择策略');
    
    // 先尝试分析页面结构
    _analyzePageStructure(document);
    
    // 策略1: 尝试常见的 CSS class 选择器
    final classSelectors = [
      '.anime-card',
      '.video-card',
      '.vodlist_item',
      '.vod-item',
      '.item',
      '.card',
      '.list-item',
    ];
    
    for (final selector in classSelectors) {
      try {
        final nodes = document.querySelectorAll(selector);
        if (nodes.length >= 3) { // 至少要有3个结果才算有效
          logger.success('✓ 降级选择器 "$selector" 找到 ${nodes.length} 个节点');
          return nodes;
        }
      } catch (e) {
        continue;
      }
    }
    
    // 策略2: 查找包含特定链接的元素
    final linkSelectors = [
      'a[href*="voddetail"]',
      'a[href*="detail"]',
      'a[href*="play"]',
      'a[href*="video"]',
      'a[href*="/v/"]',
      'a[href*="/anime/"]',
    ];
    
    for (final selector in linkSelectors) {
      try {
        final links = document.querySelectorAll(selector);
        if (links.length >= 3) {
          // 获取这些链接的父容器
          final containers = links.map((link) {
            // 向上查找合适的容器（通常是2-3层）
            dom.Element? container = link.parent;
            for (int i = 0; i < 2 && container != null; i++) {
              if (container.className.isNotEmpty || 
                  container.children.length > 1) {
                break;
              }
              container = container.parent;
            }
            return container;
          }).whereType<dom.Element>().toSet().toList();
          
          if (containers.length >= 3) {
            logger.success('✓ 通过链接 "$selector" 找到 ${containers.length} 个容器');
            return containers;
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    // 策略3: 查找包含图片和链接的 div
    try {
      final allDivs = document.querySelectorAll('div');
      final candidates = allDivs.where((div) {
        final hasImage = div.querySelector('img') != null;
        final hasLink = div.querySelector('a') != null;
        final hasText = div.text.trim().isNotEmpty;
        return hasImage && hasLink && hasText;
      }).toList();
      
      if (candidates.length >= 3) {
        logger.success('✓ 通过结构分析找到 ${candidates.length} 个候选节点');
        return candidates;
      }
    } catch (e) {
      logger.debug('结构分析失败: $e');
    }
    
    logger.warning('⚠️ 所有降级选择器都失败');
    return [];
  }
  
  /// 分析页面结构（调试用）
  void _analyzePageStructure(dom.Document document) {
    final body = document.body;
    if (body == null) return;
    
    logger.debug('页面结构分析:');
    logger.debug('  body 下有 ${body.children.length} 个直接子元素');
    
    // 分析前几层的 div 结构
    int divCount = 0;
    for (int i = 0; i < body.children.length && i < 10; i++) {
      final child = body.children[i];
      if (child.localName == 'div') {
        divCount++;
        logger.debug('  div[$divCount]: class="${child.className}", id="${child.id}", 子元素数: ${child.children.length}');
        
        // 如果是第 5 个 div，详细分析
        if (divCount == 5) {
          logger.debug('    第5个div的子元素:');
          for (int j = 0; j < child.children.length && j < 5; j++) {
            final subChild = child.children[j];
            logger.debug('      [$j] ${subChild.localName}: class="${subChild.className}"');
          }
        }
      }
    }
  }
}

/// XPath 步骤
class _XPathStep {
  final String tag;
  final int index; // 0 表示所有，>0 表示特定索引（从 1 开始）
  final bool recursive; // 是否递归查找

  const _XPathStep({
    required this.tag,
    required this.index,
    required this.recursive,
  });
}
