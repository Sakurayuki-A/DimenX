import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/anime.dart';
import '../models/source_rule.dart';

class AnimeSearchService {
  static final AnimeSearchService _instance = AnimeSearchService._internal();
  factory AnimeSearchService() => _instance;
  AnimeSearchService._internal();

  /// 根据规则搜索动漫
  Future<List<Anime>> searchAnimes(String keyword, List<SourceRule> rules) async {
    print('开始搜索: $keyword, 规则数量: ${rules.length}');
    List<Anime> allResults = [];
    
    if (rules.isEmpty) {
      print('没有配置搜索规则');
      return allResults;
    }
    
    for (final rule in rules) {
      try {
        print('使用规则搜索: ${rule.name}');
        final results = await _searchWithRule(keyword, rule);
        print('规则 ${rule.name} 返回 ${results.length} 个结果');
        allResults.addAll(results);
      } catch (e) {
        print('搜索规则 ${rule.name} 失败: $e');
      }
    }
    
    print('总共找到 ${allResults.length} 个结果');
    
    // 对结果进行相关性排序
    if (allResults.isNotEmpty) {
      allResults = _sortByRelevance(allResults, keyword);
      print('按相关性排序后保留 ${allResults.length} 个结果');
    }
    
    return allResults;
  }

  /// 使用单个规则搜索
  Future<List<Anime>> _searchWithRule(String keyword, SourceRule rule) async {
    try {
      // 构建搜索URL
      final searchUrl = rule.searchURL.replaceAll('@keyword', Uri.encodeComponent(keyword));
      print('搜索URL: $searchUrl');
      
      // 发送HTTP请求
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
      );

      print('HTTP状态码: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('HTTP请求失败: ${response.statusCode}');
      }

      print('响应内容长度: ${response.body.length}');
      // 打印前500个字符用于调试
      if (response.body.length > 0) {
        print('响应内容预览: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }

      // 解析HTML
      final document = html_parser.parse(response.body);
      print('HTML文档解析完成');
      
      // 使用XPath选择器获取搜索结果列表
      print('使用XPath选择器: ${rule.searchList}');
      final searchItems = _selectByXPath(document, rule.searchList);
      print('找到搜索项数量: ${searchItems.length}');
      
      List<Anime> animes = [];
      
      // 如果XPath选择器没有找到结果，使用智能选择器
      if (searchItems.isEmpty) {
        print('XPath选择器未找到结果，启用智能通用选择器...');
        animes = _extractWithSmartSelectors(document, rule.baseURL);
        print('智能选择器找到 ${animes.length} 个结果');
        return animes;
      }
      
      for (int i = 0; i < searchItems.length; i++) {
        final item = searchItems[i];
        print('\n=== 处理搜索项 ${i + 1} ===');
        print('HTML内容: ${item.outerHtml.substring(0, item.outerHtml.length > 200 ? 200 : item.outerHtml.length)}...');
        
        try {
          // 提取动漫名称 - 使用多层策略获取最佳标题
          String name = '未知动漫';
          List<String> candidates = [];
          
          // 策略1: 从a标签的title属性获取（最可靠）
          final linkElements = item.querySelectorAll('a');
          print('找到 ${linkElements.length} 个a标签');
          for (int j = 0; j < linkElements.length; j++) {
            var linkElement = linkElements[j];
            String titleAttr = linkElement.attributes['title'] ?? '';
            if (titleAttr.isNotEmpty) {
              candidates.add(titleAttr);
              print('a标签[$j]title属性: "$titleAttr"');
            }
          }
          
          // 策略2: 从a标签的文本内容获取
          for (int j = 0; j < linkElements.length; j++) {
            var linkElement = linkElements[j];
            String candidateName = _getTextContent(linkElement);
            if (candidateName.isNotEmpty) {
              candidates.add(candidateName);
              print('a标签[$j]文本内容: "$candidateName"');
            }
          }
          
          // 策略3: 从img标签的alt属性获取
          final imgElements = item.querySelectorAll('img');
          for (var imgElement in imgElements) {
            String altAttr = imgElement.attributes['alt'] ?? '';
            if (altAttr.isNotEmpty) {
              candidates.add(altAttr);
              print('img标签alt属性: "$altAttr"');
            }
          }
          
          // 从候选标题中选择最佳的
          for (String candidate in candidates) {
            String filteredName = _filterAnimeName(candidate);
            print('候选标题过滤: "$candidate" -> "$filteredName"');
            if (filteredName != '未知动漫' && filteredName.length > 2 && _isValidAnimeTitle(filteredName)) {
              name = filteredName;
              print('✓ 选择最佳标题: $name');
              break;
            }
          }
          
          // 如果链接中没找到合适的标题，再尝试XPath选择器
          if (name == '未知动漫') {
            print('尝试XPath选择器: ${rule.searchName}');
            final nameElements = _selectByXPath(item, rule.searchName);
            print('XPath找到 ${nameElements.length} 个元素');
            if (nameElements.isNotEmpty) {
              // 尝试从多个元素中找到最合适的标题
              for (int k = 0; k < nameElements.length; k++) {
                var element = nameElements[k];
                String candidateName = _getTextContent(element);
                print('XPath元素[$k]原始文本: "$candidateName"');
                String filteredName = _filterAnimeName(candidateName);
                print('XPath元素[$k]过滤后: "$filteredName"');
                if (filteredName != '未知动漫' && filteredName.length > 2) {
                  name = filteredName;
                  print('✓ 从XPath提取标题: $name');
                  break;
                }
              }
            }
          }
          
          // 最后尝试其他常见的标题元素
          if (name == '未知动漫') {
            final titleElements = item.querySelectorAll('h1, h2, h3, h4, .title, .name');
            for (var element in titleElements) {
              String candidateName = _getTextContent(element);
              candidateName = _filterAnimeName(candidateName);
              if (candidateName != '未知动漫' && candidateName.length > 2) {
                name = candidateName;
                print('从标题元素提取: $name');
                break;
              }
            }
          }
          
          // 过滤掉不合适的标题
          name = _filterAnimeName(name);
          print('提取到动漫名称: $name');
          
          // 提取详情页链接
          final detailLinkElements = _selectByXPath(item, rule.searchResult);
          String detailUrl = '';
          if (detailLinkElements.isNotEmpty) {
            final linkElement = detailLinkElements.first;
            detailUrl = linkElement.attributes['href'] ?? '';
          } else {
            // 如果XPath没找到，尝试查找a标签
            final aElements = item.querySelectorAll('a');
            if (aElements.isNotEmpty) {
              detailUrl = aElements.first.attributes['href'] ?? '';
            }
          }
          
          if (detailUrl.isNotEmpty && !detailUrl.startsWith('http')) {
            detailUrl = rule.baseURL.replaceAll(RegExp(r'/$'), '') + '/' + detailUrl.replaceAll(RegExp(r'^/'), '');
          }
          print('提取到链接: $detailUrl');
          
          // 提取图片URL
          final imageElements = _selectByXPath(item, rule.imgRoads);
          String imageUrl = '';
          if (imageElements.isNotEmpty) {
            final imgElement = imageElements.first;
            imageUrl = imgElement.attributes['src'] ?? imgElement.attributes['data-src'] ?? '';
          } else {
            // 如果XPath没找到，尝试查找img标签
            final imgTags = item.querySelectorAll('img');
            if (imgTags.isNotEmpty) {
              imageUrl = imgTags.first.attributes['src'] ?? imgTags.first.attributes['data-src'] ?? '';
            }
          }
          
          if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
            imageUrl = rule.baseURL.replaceAll(RegExp(r'/$'), '') + '/' + imageUrl.replaceAll(RegExp(r'^/'), '');
          }
          print('提取到图片: $imageUrl');
          
          if (name.isNotEmpty && detailUrl.isNotEmpty) {
            final anime = Anime(
              id: '${rule.name}_${i}_${DateTime.now().millisecondsSinceEpoch}',
              title: name,
              description: '来源: ${rule.name}',
              imageUrl: imageUrl,
              videoUrl: detailUrl,
              genres: [rule.name],
              rating: 0.0,
              year: DateTime.now().year,
              status: '未知',
              episodes: 0,
            );
            animes.add(anime);
          }
        } catch (e) {
          print('解析搜索项失败: $e');
          continue;
        }
      }
      
      return animes;
    } catch (e) {
      print('搜索规则 ${rule.name} 执行失败: $e');
      return [];
    }
  }

  /// 增强的XPath选择器实现
  List<dom.Element> _selectByXPath(dom.Node context, String xpath) {
    try {
      print('解析XPath: $xpath');
      
      // 如果是文档级别的查询，先尝试智能选择器作为备用
      if (context is dom.Document && xpath.contains('div[2]')) {
        print('检测到复杂XPath，尝试精确解析...');
        final result = _parseComplexXPath(context, xpath);
        if (result.isNotEmpty) {
          return result;
        }
        
        // 如果XPath失败，使用智能选择器
        print('XPath解析失败，使用智能选择器作为备用...');
        final smartResults = _extractWithSmartSelectors(context, '');
        return smartResults.map((anime) {
          // 创建虚拟元素来包装结果
          final element = dom.Element.tag('div');
          element.attributes['data-title'] = anime.title;
          element.attributes['data-url'] = anime.detailUrl;
          element.attributes['data-image'] = anime.imageUrl;
          return element;
        }).toList();
      }
      
      return _parseComplexXPath(context, xpath);
    } catch (e) {
      print('XPath选择器解析失败: $xpath, 错误: $e');
      return [];
    }
  }
  
  /// 解析复杂的XPath表达式
  List<dom.Element> _parseComplexXPath(dom.Node context, String xpath) {
    // 处理包含text()的XPath
    if (xpath.contains('/text()')) {
      final pathWithoutText = xpath.replaceAll('/text()', '');
      print('处理text()节点，路径: $pathWithoutText');
      return _parseComplexXPath(context, pathWithoutText);
    }
    
    // 处理 //div[2]/div[2]/div[2]/div[2]/div 这样的路径
    if (xpath.startsWith('//')) {
      return _parseRecursiveXPath(context, xpath.substring(2));
    } else {
      return _parseAbsoluteXPath(context, xpath);
    }
  }
  
  /// 解析递归XPath (以//开头)
  List<dom.Element> _parseRecursiveXPath(dom.Node context, String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return [];
    
    // 第一部分：递归查找所有匹配的起始元素
    final firstPart = parts[0];
    List<dom.Element> candidates = [];
    
    if (context is dom.Document) {
      candidates = _findAllMatchingElements(context.documentElement!, firstPart);
    } else if (context is dom.Element) {
      candidates = _findAllMatchingElements(context, firstPart);
    }
    
    print('递归查找 "$firstPart" 找到 ${candidates.length} 个候选元素');
    
    // 后续部分：按路径逐层筛选
    List<dom.Element> current = candidates;
    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      List<dom.Element> next = [];
      
      for (final element in current) {
        final children = _selectDirectChildren(element, part);
        next.addAll(children);
        
        // 调试信息：显示找到的子元素
        if (children.isNotEmpty) {
          print('元素 ${element.localName} 的子元素 "$part": ${children.length} 个');
          for (int j = 0; j < children.length && j < 3; j++) {
            final child = children[j];
            final text = child.text.trim();
            print('  子元素[$j]: ${child.localName}, 文本: "${text.length > 50 ? text.substring(0, 50) + '...' : text}"');
          }
        }
      }
      
      current = next;
      print('路径 "${parts.sublist(0, i + 1).join('/')}" 找到 ${current.length} 个元素');
      
      if (current.isEmpty) break;
    }
    
    // 最终结果调试
    if (current.isNotEmpty) {
      print('最终找到 ${current.length} 个元素:');
      for (int i = 0; i < current.length && i < 5; i++) {
        final element = current[i];
        final text = element.text.trim();
        print('  结果[$i]: ${element.localName}, 文本: "${text.length > 100 ? text.substring(0, 100) + '...' : text}"');
      }
    }
    
    return current;
  }
  
  /// 查找所有匹配指定条件的元素
  List<dom.Element> _findAllMatchingElements(dom.Element root, String condition) {
    final result = <dom.Element>[];
    
    // 检查当前元素
    if (_matchesCondition(root, condition)) {
      result.add(root);
    }
    
    // 递归检查所有子元素
    for (final child in root.children) {
      result.addAll(_findAllMatchingElements(child, condition));
    }
    
    return result;
  }
  
  /// 选择直接子元素
  List<dom.Element> _selectDirectChildren(dom.Element parent, String condition) {
    final result = <dom.Element>[];
    
    // 处理text()节点 - 返回包含文本的元素本身
    if (condition == 'text()') {
      if (parent.text.trim().isNotEmpty) {
        result.add(parent);
      }
      return result;
    }
    
    if (condition.contains('[') && condition.contains(']')) {
      // 处理索引条件，如 div[2]
      final match = RegExp(r'(\w+)\[(\d+)\]').firstMatch(condition);
      if (match != null) {
        final tagName = match.group(1)!;
        final index = int.parse(match.group(2)!) - 1; // XPath索引从1开始
        
        final children = parent.children
            .where((e) => e.localName == tagName)
            .toList();
        
        if (index >= 0 && index < children.length) {
          result.add(children[index]);
        }
      }
    } else {
      // 普通标签选择
      result.addAll(parent.children.where((e) => e.localName == condition));
    }
    
    return result;
  }
  
  /// 检查元素是否匹配条件
  bool _matchesCondition(dom.Element element, String condition) {
    if (condition.contains('[') && condition.contains(']')) {
      // 处理带条件的匹配
      final match = RegExp(r'(\w+)\[(\d+)\]').firstMatch(condition);
      if (match != null) {
        final tagName = match.group(1)!;
        return element.localName == tagName;
      }
      
      // 处理属性条件
      final attrMatch = RegExp(r'(\w+)\[@(\w+)="([^"]+)"\]').firstMatch(condition);
      if (attrMatch != null) {
        final tagName = attrMatch.group(1)!;
        final attrName = attrMatch.group(2)!;
        final attrValue = attrMatch.group(3)!;
        return element.localName == tagName && 
               element.attributes[attrName] == attrValue;
      }
    } else {
      // 简单标签匹配
      return element.localName == condition;
    }
    
    return false;
  }
  
  /// 解析绝对XPath
  List<dom.Element> _parseAbsoluteXPath(dom.Node context, String path) {
    // 暂时使用原有的实现
    return _selectElements(context, path);
  }

  /// 选择元素的辅助方法
  List<dom.Element> _selectElements(dom.Node context, String selector) {
    List<dom.Element> results = [];
    
    try {
      // 将XPath转换为CSS选择器的简化实现
      String cssSelector = _xpathToCss(selector);
      
      if (context is dom.Document) {
        results = context.querySelectorAll(cssSelector);
      } else if (context is dom.Element) {
        results = context.querySelectorAll(cssSelector);
      }
    } catch (e) {
      // 如果CSS选择器失败，尝试直接遍历
      if (context is dom.Element) {
        results = _findElementsByPath(context, selector.split('/'));
      } else if (context is dom.Document) {
        results = _findElementsByPath(context.documentElement!, selector.split('/'));
      }
    }
    
    return results;
  }

  /// 简化的XPath到CSS选择器转换
  String _xpathToCss(String xpath) {
    String css = xpath;
    
    // 处理基本的XPath表达式
    css = css.replaceAllMapped(RegExp(r'(\w+)\[(\d+)\]'), (match) {
      final tag = match.group(1);
      final index = int.parse(match.group(2)!) - 1; // XPath索引从1开始，CSS从0开始
      return '$tag:nth-of-type(${index + 1})';
    });
    
    // 处理属性选择器
    css = css.replaceAllMapped(RegExp(r'(\w+)\[@(\w+)="([^"]+)"\]'), (match) {
      final tag = match.group(1);
      final attr = match.group(2);
      final value = match.group(3);
      return '$tag[$attr="$value"]';
    });
    
    // 处理类选择器
    css = css.replaceAllMapped(RegExp(r'(\w+)\[@class="([^"]+)"\]'), (match) {
      final tag = match.group(1);
      final className = match.group(2);
      return '$tag.$className';
    });
    
    // 将 / 替换为 >
    css = css.replaceAll('/', ' > ');
    
    return css;
  }

  /// 通过路径查找元素
  List<dom.Element> _findElementsByPath(dom.Element root, List<String> pathParts) {
    List<dom.Element> current = [root];
    
    for (String part in pathParts) {
      if (part.isEmpty) continue;
      
      List<dom.Element> next = [];
      
      for (dom.Element element in current) {
        // 处理索引选择器 div[2]
        final indexMatch = RegExp(r'(\w+)\[(\d+)\]').firstMatch(part);
        if (indexMatch != null) {
          final tagName = indexMatch.group(1)!;
          final index = int.parse(indexMatch.group(2)!) - 1;
          
          final children = element.children.where((e) => e.localName == tagName).toList();
          if (index >= 0 && index < children.length) {
            next.add(children[index]);
          }
        } else {
          // 普通标签选择
          next.addAll(element.children.where((e) => e.localName == part));
        }
      }
      
      current = next;
    }
    
    return current;
  }

  /// 获取元素的文本内容
  String _getTextContent(dom.Element element) {
    return element.text.trim();
  }

  /// 按相关性对搜索结果排序
  List<Anime> _sortByRelevance(List<Anime> animes, String keyword) {
    final List<Map<String, dynamic>> scoredResults = [];
    
    for (final anime in animes) {
      final score = _calculateRelevanceScore(anime.title, keyword);
      if (score > 0) { // 只保留有相关性的结果
        scoredResults.add({
          'anime': anime,
          'score': score,
        });
        print('${anime.title} - 相关性评分: $score');
      } else {
        print('过滤掉不相关结果: ${anime.title}');
      }
    }
    
    // 按评分排序
    scoredResults.sort((a, b) => b['score'].compareTo(a['score']));
    
    // 返回排序后的动漫列表
    return scoredResults.map((result) => result['anime'] as Anime).toList();
  }
  
  /// 计算标题与关键词的相关性评分
  double _calculateRelevanceScore(String title, String keyword) {
    final lowerTitle = title.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    double score = 0.0;
    
    print('计算相关性: "$title" vs "$keyword"');
    
    // 完全匹配得分最高
    if (lowerTitle == lowerKeyword) {
      score += 100.0;
      print('  完全匹配: +100.0');
    }
    // 标题开头匹配
    else if (lowerTitle.startsWith(lowerKeyword)) {
      score += 80.0;
      print('  开头匹配: +80.0');
    }
    // 标题包含完整关键词
    else if (lowerTitle.contains(lowerKeyword)) {
      score += 60.0;
      print('  包含匹配: +60.0');
    }
    
    // 检查关键词的各个部分
    final keywordParts = lowerKeyword.split(RegExp(r'[\s\-_]+'));
    int matchedParts = 0;
    
    for (final part in keywordParts) {
      if (part.isNotEmpty && lowerTitle.contains(part)) {
        matchedParts++;
        score += 15.0;
        print('  部分匹配 "$part": +15.0');
      }
    }
    
    // 如果关键词有多个部分，检查匹配比例
    if (keywordParts.length > 1) {
      final matchRatio = matchedParts / keywordParts.length;
      if (matchRatio < 0.6) {
        score *= 0.5; // 降低评分
        print('  匹配比例低: ×0.5');
      }
    }
    
    // 强化续集惩罚机制
    if (!lowerKeyword.contains('第') && !lowerKeyword.contains('季') && 
        !lowerKeyword.contains('season') && !lowerKeyword.contains('s2') && 
        !lowerKeyword.contains('s3') && !lowerKeyword.contains('2') && 
        !lowerKeyword.contains('二')) {
      
      // 检查是否为续集
      bool isSequel = false;
      final sequelPatterns = [
        '第二季', '第三季', '第四季', '第五季',
        'season 2', 'season 3', 'season 4', 'season 5',
        's2', 's3', 's4', 's5',
        '2nd season', '3rd season', '4th season',
        'ii', 'iii', 'iv', 'v',
        '2期', '3期', '4期', '5期',
        '续', '新', '再'
      ];
      
      for (final pattern in sequelPatterns) {
        if (lowerTitle.contains(pattern)) {
          isSequel = true;
          print('  检测到续集标识: "$pattern"');
          break;
        }
      }
      
      if (isSequel) {
        // 如果关键词完全匹配基础名称，续集应该得到更严厉的惩罚
        final baseTitle = lowerTitle.replaceAll(RegExp(r'第[二三四五]季|season [2-5]|s[2-5]|2nd season|3rd season|4th season|ii|iii|iv|v|[2-5]期'), '').trim();
        if (baseTitle == lowerKeyword || baseTitle.startsWith(lowerKeyword)) {
          score *= 0.1; // 极大降低续集评分
          print('  严厉续集惩罚: ×0.1 (基础名称匹配)');
        } else {
          score *= 0.3; // 一般续集惩罚
          print('  一般续集惩罚: ×0.3');
        }
      }
    }
    
    // 额外的精确匹配奖励
    if (lowerTitle == lowerKeyword) {
      score += 50.0; // 额外奖励精确匹配
      print('  精确匹配奖励: +50.0');
    }
    
    // 长度相似性奖励（避免过长标题获得高分）
    final lengthDiff = (lowerTitle.length - lowerKeyword.length).abs();
    if (lengthDiff <= 2) {
      score += 20.0; // 长度相似奖励
      print('  长度相似奖励: +20.0');
    } else if (lengthDiff > 10) {
      score *= 0.8; // 长度差异惩罚
      print('  长度差异惩罚: ×0.8');
    }
    
    // 过滤掉评分过低的结果
    if (score < 15.0) {
      print('  最终评分过低，过滤: $score');
      return 0.0; // 不相关
    }
    
    print('  最终评分: $score');
    return score;
  }

  /// 过滤动漫名称，排除不合适的内容
  String _filterAnimeName(String name) {
    // 清理空白字符
    name = name.trim();
    
    // 如果名称为空，返回默认值
    if (name.isEmpty) {
      return '未知动漫';
    }
    
    print('原始名称: "$name"');
    
    // 按行分割，寻找最可能的标题行
    final lines = name.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    if (lines.length > 1) {
      print('多行文本，行数: ${lines.length}');
      for (int i = 0; i < lines.length; i++) {
        print('  行[$i]: "${lines[i]}"');
      }
      
      // 寻找最可能的标题行（通常不是状态信息）
      for (final line in lines) {
        if (!_isStatusText(line) && line.length > 2) {
          name = line;
          print('选择标题行: "$name"');
          break;
        }
      }
    }
    
    // 定义需要过滤的关键词
    final List<String> filterKeywords = [
      '已完结',
      '更新中',
      '连载中',
      '完结',
      '更新',
      '连载',
      '全集',
      '高清',
      '蓝光',
      'HD',
      'BD',
      '字幕',
      '中字',
      '日语',
      '国语',
      '粤语',
      '内详',
      '详情',
      '播放',
      '观看',
      '在线',
      '免费',
      '最新',
      '热门',
      '推荐',
      '豆瓣',
      '高分',
      '正片',
      '电影',
      '电视剧',
      '综艺',
      '纪录片',
      '动画片',
      '卡通',
      '动漫',
      '番剧',
      '国产',
      '日本',
      '美国',
      '韩国',
      '欧美',
      '大陆',
      '港台',
      '海外',
      '原创',
      '独家',
      '首播',
      '预告',
      '花絮',
      '幕后',
      '制作',
      '特辑',
      '精彩',
      '经典',
      '必看',
      '神作',
      '佳作',
      '力作',
      '巨作',
      '好评',
      '口碑',
      '评分',
      '排行',
      '榜单',
      '合集',
      '系列',
      '专题',
      '特别',
      '限定',
      '珍藏',
      '收藏',
      '精选',
      '优选',
      '甄选',
    ];
    
    // 移除状态关键词
    for (final keyword in filterKeywords) {
      if (name.contains(keyword)) {
        print('移除关键词: "$keyword"');
        name = name.replaceAll(keyword, '').trim();
      }
    }
    
    // 检查是否只包含过滤关键词或者是无意义的短语
    for (String keyword in filterKeywords) {
      if (name == keyword || 
          (name.length <= keyword.length + 2 && name.contains(keyword))) {
        print('过滤掉无效标题: $name');
        return '未知动漫';
      }
    }
    
    // 移除多余的空白字符
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // 如果处理后名称太短，可能不是有效的动漫名称
    if (name.length < 2) {
      print('过滤后名称太短');
      return '未知动漫';
    }
    
    print('最终名称: "$name"');
    return name;
  }
  
  /// 判断是否为状态文本
  bool _isStatusText(String text) {
    final statusPatterns = [
      '已完结',
      '连载中',
      '更新中',
      '完结',
      '连载',
      '更新',
      '全集',
    ];
    
    for (final pattern in statusPatterns) {
      if (text.contains(pattern)) return true;
    }
    
    // 检查是否为纯数字集数信息
    if (RegExp(r'^\d+集$').hasMatch(text)) return true;
    if (RegExp(r'^共\d+集$').hasMatch(text)) return true;
    if (RegExp(r'^更新至\d+集$').hasMatch(text)) return true;
    if (RegExp(r'^\d{4}年$').hasMatch(text)) return true;
    
    return false;
  }
  
  /// 验证是否为有效的动漫标题
  bool _isValidAnimeTitle(String title) {
    // 过滤掉明显不是动漫标题的文本
    final invalidPatterns = [
      '豆瓣高分正片',
      '豆瓣高分',
      '正片',
      '电影合集',
      '电视剧合集',
      '动漫合集',
      '番剧合集',
      '精选合集',
      '热门推荐',
      '最新更新',
      '排行榜',
      '专题',
      '分类',
      '标签',
      '频道',
      '栏目',
      '版块',
      '区域',
      '类型',
      '年份',
      '地区',
      '语言',
      '更多',
      '查看更多',
      '全部',
      '所有',
      '其他',
      '相关',
      '推荐',
      '猜你喜欢',
      '为你推荐',
      '热门搜索',
      '搜索历史',
      '最近观看',
      '收藏夹',
      '播放列表',
      '观看记录',
      '我的',
      '个人中心',
      '设置',
      '帮助',
      '关于',
      '联系我们',
      '意见反馈',
      '版权声明',
      '免责声明',
      '用户协议',
      '隐私政策',
    ];
    
    final lowerTitle = title.toLowerCase();
    
    // 检查是否包含无效模式
    for (final pattern in invalidPatterns) {
      if (lowerTitle.contains(pattern.toLowerCase())) {
        print('检测到无效标题模式: "$pattern" in "$title"');
        return false;
      }
    }
    
    // 检查是否只包含数字、符号或过短
    if (title.length < 2) {
      return false;
    }
    
    // 检查是否只包含特殊字符
    if (RegExp(r'^[\d\s\-_\.\,\!\?\(\)\[\]\{\}]+$').hasMatch(title)) {
      return false;
    }
    
    // 检查是否为纯英文且过短（可能是按钮文字）
    if (RegExp(r'^[a-zA-Z\s]{1,5}$').hasMatch(title)) {
      return false;
    }
    
    return true;
  }
  
  /// 智能通用选择器 - 自动适配不同网站结构
  List<Anime> _extractWithSmartSelectors(dom.Document document, String baseUrl) {
    final results = <Anime>[];
    
    print('开始智能选择器分析...');
    // 策略1：查找包含链接的通用容器
    final selectors = [
      'div[class*="video"]:not([class*="time"]):not([class*="view"])',
      'div[class*="anime"]',
      'div[class*="item"]',
      'div[class*="card"]',
      'li:has(a)',
      'article:has(a)',
      'div:has(a[href*="detail"])',
      'div:has(a[href*="show"])',
    ];
    
    for (final selector in selectors) {
      try {
        final elements = document.querySelectorAll(selector);
        print('选择器 "$selector" 找到 ${elements.length} 个元素');
        
        for (final element in elements) {
          final anime = _extractAnimeFromContainer(element, baseUrl);
          if (anime != null) {
            results.add(anime);
          }
          if (results.length >= 10) break;
        }
        
        if (results.length >= 5) break; // 找到足够结果就停止
      } catch (e) {
        print('选择器 "$selector" 执行失败: $e');
      }
    }
    
    print('智能选择器提取完成，共找到 ${results.length} 个结果');
    return _removeDuplicateAnimes(results);
  }
  
  /// 从容器元素中提取动漫信息
  Anime? _extractAnimeFromContainer(dom.Element container, String baseUrl) {
    try {
      // 查找链接
      final link = container.querySelector('a[href]');
      if (link == null) return null;
      
      // 提取标题
      String title = '';
      
      // 1. 从title属性
      title = link.attributes['title'] ?? '';
      
      // 2. 从链接文本
      if (title.isEmpty) {
        title = link.text.trim();
      }
      
      // 3. 从图片alt属性
      if (title.isEmpty) {
        final img = container.querySelector('img[alt]');
        if (img != null) {
          title = img.attributes['alt'] ?? '';
        }
      }
      
      // 4. 从标题元素
      if (title.isEmpty) {
        final titleEl = container.querySelector('h1, h2, h3, h4, h5, h6, .title, .name');
        if (titleEl != null) {
          title = titleEl.text.trim();
        }
      }
      
      if (title.isEmpty) return null;
      
      // 提取URL
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty) return null;
      
      final detailUrl = _makeAbsoluteUrl(href, baseUrl);
      
      // 提取图片
      String imageUrl = '';
      final img = container.querySelector('img[src]');
      if (img != null) {
        imageUrl = _makeAbsoluteUrl(img.attributes['src'] ?? '', baseUrl);
      }
      
      return Anime(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _filterAnimeName(title),
        detailUrl: detailUrl,
        imageUrl: imageUrl,
        description: '',
        rating: 0.0,
        year: DateTime.now().year,
        status: '',
      );
    } catch (e) {
      print('提取动漫信息失败: $e');
      return null;
    }
  }
  
  /// 将相对URL转换为绝对URL
  String _makeAbsoluteUrl(String url, String baseUrl) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    
    try {
      final base = Uri.parse(baseUrl);
      final resolved = base.resolve(url);
      return resolved.toString();
    } catch (e) {
      print('URL解析失败: $e');
      return url;
    }
  }
  
  /// 去除重复的动漫结果
  List<Anime> _removeDuplicateAnimes(List<Anime> animes) {
    final seen = <String>{};
    final deduplicated = <Anime>[];
    
    for (final anime in animes) {
      final key = anime.title.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        deduplicated.add(anime);
      }
    }
    
    return deduplicated;
  }
}
