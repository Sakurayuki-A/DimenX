import 'package:flutter/material.dart';
import '../models/anime.dart';
import '../services/bangumi_api_service.dart';

class AnimeProvider with ChangeNotifier {
  List<Anime> _animes = [];
  List<Anime> _searchResults = [];
  List<Anime> _bangumiRecommendations = []; // Bangumi推荐
  bool _isLoading = false;
  String _error = '';
  final BangumiApiService _bangumiService = BangumiApiService();

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

  /// 加载Bangumi推荐数据
  Future<void> _loadBangumiRecommendations() async {
    try {
      print('AnimeProvider: 开始加载Bangumi推荐数据');
      
      // 获取当季动画作为推荐内容
      final seasonalAnime = await _bangumiService.getSeasonalAnime(limit: 20);
      
      _bangumiRecommendations = seasonalAnime;
      
      print('AnimeProvider: 成功加载 ${_bangumiRecommendations.length} 个Bangumi推荐');
    } catch (e) {
      print('AnimeProvider: 加载Bangumi推荐失败: $e');
      _bangumiRecommendations = [];
      // 不抛出异常，允许应用继续使用模拟数据
    }
  }

  Future<void> searchAnimes(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      // 只搜索Bangumi
      print('开始搜索Bangumi: $query');
      _searchResults = await _bangumiService.searchAnime(query, limit: 20);
      
      print('Bangumi搜索完成，共 ${_searchResults.length} 个结果');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = '搜索失败: $e';
      _searchResults = [];
      _isLoading = false;
      notifyListeners();
    }
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
