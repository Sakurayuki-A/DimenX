import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/anime.dart';

class FavoritesProvider with ChangeNotifier {
  List<Anime> _favorites = [];
  
  List<Anime> get favorites => _favorites;

  Future<void> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList('favorites') ?? [];
      
      _favorites = favoritesJson
          .map((jsonStr) => Anime.fromJson(json.decode(jsonStr)))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('加载收藏失败: $e');
    }
  }

  Future<void> addToFavorites(Anime anime) async {
    if (!_favorites.any((fav) => fav.id == anime.id)) {
      _favorites.add(anime);
      await _saveFavorites();
      notifyListeners();
    }
  }

  Future<void> removeFromFavorites(String animeId) async {
    _favorites.removeWhere((anime) => anime.id == animeId);
    await _saveFavorites();
    notifyListeners();
  }

  bool isFavorite(String animeId) {
    return _favorites.any((anime) => anime.id == animeId);
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = _favorites
          .map((anime) => json.encode(anime.toJson()))
          .toList();
      
      await prefs.setStringList('favorites', favoritesJson);
    } catch (e) {
      print('保存收藏失败: $e');
    }
  }

  Future<void> toggleFavorite(Anime anime) async {
    if (isFavorite(anime.id)) {
      await removeFromFavorites(anime.id);
    } else {
      await addToFavorites(anime);
    }
  }
}
