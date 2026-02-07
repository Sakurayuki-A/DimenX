import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/anime.dart';

class HistoryItem {
  final Anime anime;
  final DateTime watchedAt;
  final Duration watchedDuration;

  HistoryItem({
    required this.anime,
    required this.watchedAt,
    required this.watchedDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'anime': anime.toJson(),
      'watchedAt': watchedAt.millisecondsSinceEpoch,
      'watchedDuration': watchedDuration.inSeconds,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      anime: Anime.fromJson(json['anime']),
      watchedAt: DateTime.fromMillisecondsSinceEpoch(json['watchedAt']),
      watchedDuration: Duration(seconds: json['watchedDuration']),
    );
  }
}

class HistoryProvider with ChangeNotifier {
  List<HistoryItem> _history = [];
  
  List<HistoryItem> get history => _history;

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('history') ?? [];
      
      _history = historyJson
          .map((jsonStr) => HistoryItem.fromJson(json.decode(jsonStr)))
          .toList();
      
      // 去重处理（按标题去重，保留最新的记录）
      _deduplicateHistory();
      
      // 按观看时间倒序排列
      _history.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
      
      notifyListeners();
    } catch (e) {
      print('加载历史记录失败: $e');
    }
  }
  
  /// 去重历史记录
  void _deduplicateHistory() {
    final Map<String, HistoryItem> uniqueHistory = {};
    
    // 按观看时间倒序排列，确保保留最新的记录
    _history.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    
    for (final item in _history) {
      final key = item.anime.title.trim().toLowerCase();
      if (!uniqueHistory.containsKey(key)) {
        uniqueHistory[key] = item;
      }
    }
    
    _history = uniqueHistory.values.toList();
    print('历史记录去重完成，从 ${_history.length} 条记录去重到 ${uniqueHistory.length} 条');
  }

  Future<void> addToHistory(Anime anime, {Duration? watchedDuration}) async {
    // 移除已存在的相同动漫记录（按ID和标题去重）
    _history.removeWhere((item) => 
      item.anime.id == anime.id || 
      item.anime.title.trim().toLowerCase() == anime.title.trim().toLowerCase()
    );
    
    // 添加新记录到开头
    _history.insert(0, HistoryItem(
      anime: anime,
      watchedAt: DateTime.now(),
      watchedDuration: watchedDuration ?? Duration.zero,
    ));
    
    // 限制历史记录数量（最多保存100条）
    if (_history.length > 100) {
      _history = _history.take(100).toList();
    }
    
    await _saveHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String animeId) async {
    _history.removeWhere((item) => item.anime.id == animeId);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }
  
  /// 手动清理重复记录
  Future<void> cleanupDuplicates() async {
    final originalCount = _history.length;
    _deduplicateHistory();
    await _saveHistory();
    notifyListeners();
    print('清理完成：从 $originalCount 条记录清理到 ${_history.length} 条');
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = _history
          .map((item) => json.encode(item.toJson()))
          .toList();
      
      await prefs.setStringList('history', historyJson);
    } catch (e) {
      print('保存历史记录失败: $e');
    }
  }

  HistoryItem? getHistoryItem(String animeId) {
    try {
      return _history.firstWhere((item) => item.anime.id == animeId);
    } catch (e) {
      return null;
    }
  }
}
