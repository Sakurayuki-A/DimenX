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
          searchList: '//div/div[3]',
          searchName: '//div[3]/div/div[*]/div/a/text()',
          searchResult: '//a',
          imgRoads: '//div/div[3]/div/div[1]/div/div/div[1]/img',
          chapterRoads: '//*[@id="线路一"]',
          chapterResult: '//a',
        ));

        _rules.add(SourceRule(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: 'xf',
          version: '1.0.0',
          baseURL: 'https://dm.xifanacg.com',
          searchURL: 'https://dm.xifanacg.com/search.html?wd=@keyword',
          searchList: '//div[5]/div/div',
          searchName: '//div[5]/div/div/div/div[2]/a/h3',
          searchResult: '//div[5]/div/div/div/div[2]/a',
          imgRoads: '//div[5]/div/div/div/div[1]/div/img',
          chapterRoads: '//div[6]/div[2]/div[2]/div[1]/div/ul/li/a',
          chapterResult: '//div[6]/div[2]/div[2]/div[1]/div/ul/li/a',
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
