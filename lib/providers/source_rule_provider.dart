import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/source_rule.dart';

class SourceRuleProvider extends ChangeNotifier {
  List<SourceRule> _rules = [];
  
  List<SourceRule> get rules => _rules;

  SourceRuleProvider() {
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = prefs.getStringList('source_rules') ?? [];
      
      _rules = rulesJson.map((ruleString) {
        final Map<String, dynamic> ruleMap = json.decode(ruleString);
        return SourceRule.fromJson(ruleMap);
      }).toList();
      
      // 如果没有规则，添加默认规则
      if (_rules.isEmpty) {
        // 默认规则1: 7sefun
        _rules.add(SourceRule(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '7sefun',
          version: '1.0.0',
          baseURL: 'https://7sefun.top/',
          searchURL: 'https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
          searchList: '//div[2]/div[2]/div[2]/div[2]/div',
          searchName: '//div[2]/text()',
          searchResult: '//a',
          imgRoads: '//img',
          chapterRoads: '//div[2]/div[2]/div[2]/div/div[2]/div[1]/div[2]',
          chapterResult: '//a',
        ));
        
        _rules.add(SourceRule(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: 'fant',
          version: '1.0.0',
          baseURL: 'https://acgfta.com/',
          searchURL: 'https://acgfta.com/search.html?wd=@keyword',
          searchList: '//div/div[3]/div',
          searchName: '//div[3]/div/div[1]/div/a/text()',
          searchResult: '//a',
          imgRoads: '//div/div[3]/div/div[1]/div/div/div[1]/img',
          chapterRoads: '//div/div[4]/div[2]/div[2]',
          chapterResult: '//a',
        ));

        _rules.add(SourceRule(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: 'hm',
          version: '1.0.0',
          baseURL: 'https://www.baimaodm.com/',
          searchURL: 'https://www.baimaodm.com/s_all?ex=1&kw=@keyword',
          searchList: '//div[4]/div[2]/div[1]/ul',
          searchName: '//div[4]/div[2]/div[1]/ul/li[1]/h2/a',
          searchResult: '//div[4]/div[2]/div[1]/ul/li[1]/a',
          imgRoads: '//div[4]/div[2]/div[1]/ul/li[1]/a/img',
          chapterRoads: '//*[@id="main0"]/div[1]/ul',
          chapterResult: '//*[@id="main0"]/div[1]/ul/li[1]/a',
        ));

        _rules.add(SourceRule(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: 'a7',
          version: '1.0.0',
          baseURL: 'https://anime7.top/',
          searchURL: 'https://anime7.top/vod-search/?wd=@keyword',
          searchList: '//div[2]/div/div[2]/div/div[2]/div[1]/div/div[2]/div/ul/li',
          searchName: '//*[@id="conch-content"]/div/div[2]/div/div[2]/div[1]/div/div[2]/div/ul/li[3]/div/div/div[2]/div[1]/a',
          searchResult: '//*[@id="conch-content"]/div/div[2]/div/div[2]/div[1]/div/div[2]/div/ul/li[3]/div/div/div[1]/a',
          imgRoads: '//a',
          chapterRoads: '//*[@id="hl-plays-list"]/li[1]',
          chapterResult: '//*[@id="hl-plays-list"]/li[1]/a',
        ));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('加载规则配置失败: $e');
    }
  }

  Future<void> _saveRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesJson = _rules.map((rule) => json.encode(rule.toJson())).toList();
      await prefs.setStringList('source_rules', rulesJson);
    } catch (e) {
      debugPrint('保存规则配置失败: $e');
    }
  }

  void addRule(SourceRule rule) {
    _rules.add(rule);
    _saveRules();
    notifyListeners();
  }

  void updateRule(int index, SourceRule rule) {
    if (index >= 0 && index < _rules.length) {
      _rules[index] = rule;
      _saveRules();
      notifyListeners();
    }
  }

  void removeRule(int index) {
    if (index >= 0 && index < _rules.length) {
      _rules.removeAt(index);
      _saveRules();
      notifyListeners();
    }
  }

  void clearRules() {
    _rules.clear();
    _saveRules();
    notifyListeners();
  }
}
