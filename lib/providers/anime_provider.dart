import 'package:flutter/material.dart';
import 'dart:async';
import '../models/anime.dart';
import '../services/bangumi_api_service.dart';

class AnimeProvider with ChangeNotifier {
  List<Anime> _animes = [];
  List<Anime> _searchResults = [];
  List<Anime> _bangumiRecommendations = []; // Bangumi推荐
  bool _isLoading = false;
  String _error = '';
  final BangumiApiService _bangumiService = BangumiApiService();
  
  // 防抖定时器
  Timer? _searchDebounceTimer;
  String? _lastSearchQuery;

  List<Anime> get animes => _animes;
  List<Anime> get searchResults => _searchResults;
  List<Anime> get bangumiRecommendations => _bangumiRecommendations; // 新增
  bool get isLoading => _isLoading;
  String get error => _error;

  // 模拟数据已清空 - 现在主要使用Bangumi推荐数据
  final List<Map<String, dynamic>> _mockData = [];

  Future<void> loadAnimes() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      // 同时加载模拟数据和Bangumi推荐
      await Future.wait([
        _loadMockData(),
        _loadBangumiRecommendations(),
      ]);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '加载动漫数据失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载模拟数据
  Future<void> _loadMockData() async {
    // 模拟网络延迟
    await Future.delayed(const Duration(seconds: 1));
    
    // 将模拟数据转换为Anime对象
    _animes = _mockData.map((data) => Anime.fromJson(data)).toList();
  }

  /// 加载Bangumi推荐数据（使用热度排序）
  Future<void> _loadBangumiRecommendations() async {
    try {
      print('AnimeProvider: 开始加载Bangumi热门推荐');
      
      // 使用热度排序获取推荐内容
      final hotAnime = await _bangumiService.getHotAnime(limit: 20);
      
      _bangumiRecommendations = hotAnime;
      
      print('AnimeProvider: 成功加载 ${_bangumiRecommendations.length} 个热门推荐');
    } catch (e) {
      print('AnimeProvider: 加载热门推荐失败: $e');
      _bangumiRecommendations = [];
      // 不抛出异常，允许应用继续使用模拟数据
    }
  }

  /// 搜索动画（带防抖）
  Future<void> searchAnimes(String query) async {
    // 取消之前的搜索定时器
    _searchDebounceTimer?.cancel();
    
    if (query.isEmpty) {
      _searchResults = [];
      _lastSearchQuery = null;
      notifyListeners();
      return;
    }
    
    // 如果查询相同，不重复搜索
    if (_lastSearchQuery == query && _searchResults.isNotEmpty) {
      print('⏭️ 跳过重复搜索: $query');
      return;
    }
    
    // 设置防抖延迟（500毫秒）
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSearch(query);
    });
  }
  
  /// 执行实际的搜索
  Future<void> _performSearch(String query) async {
    _isLoading = true;
    _error = '';
    _lastSearchQuery = query;
    notifyListeners();

    try {
      // 只搜索Bangumi
      print('🔍 开始搜索Bangumi: $query');
      _searchResults = await _bangumiService.searchAnime(query, limit: 20);
      
      print('✓ Bangumi搜索完成，共 ${_searchResults.length} 个结果');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '搜索失败: $e';
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Anime? getAnimeById(String id) {
    try {
      return _animes.firstWhere((anime) => anime.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}
