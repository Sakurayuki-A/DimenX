import 'dart:convert';
import 'package:http/http.dart' as http;

/// 制作人员数据模型
class BangumiStaff {
  final String name;
  final String role;
  final String image;
  
  BangumiStaff({
    required this.name,
    required this.role,
    this.image = '',
  });
  
  factory BangumiStaff.fromJson(Map<String, dynamic> json) {
    return BangumiStaff(
      name: json['name'] ?? '',
      role: json['relation'] ?? '',
      image: json['images']?['large'] ?? json['images']?['medium'] ?? '',
    );
  }
}

/// 角色数据模型
class BangumiCharacter {
  final String name;
  final String role;
  final String image;
  final String actor;
  
  BangumiCharacter({
    required this.name,
    required this.role,
    this.image = '',
    this.actor = '',
  });
  
  factory BangumiCharacter.fromJson(Map<String, dynamic> json) {
    String actorName = '';
    if (json['actors'] != null && json['actors'] is List && (json['actors'] as List).isNotEmpty) {
      actorName = json['actors'][0]['name'] ?? '';
    }
    
    return BangumiCharacter(
      name: json['name'] ?? '',
      role: json['relation'] ?? '',
      image: json['images']?['large'] ?? json['images']?['medium'] ?? '',
      actor: actorName,
    );
  }
}

/// 缓存项
class _CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration expiry;
  
  _CacheItem(this.data, this.expiry) : timestamp = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(timestamp) > expiry;
}

/// Bangumi评论服务
class BangumiCommentService {
  static const String baseUrl = 'https://api.bgm.tv';
  
  // 缓存
  static final Map<int, _CacheItem<int?>> _bangumiIdCache = {};
  static final Map<int, _CacheItem<List<BangumiStaff>>> _staffCache = {};
  static final Map<int, _CacheItem<List<BangumiCharacter>>> _charactersCache = {};
  
  // 缓存过期时间
  static const Duration _idCacheExpiry = Duration(hours: 24);
  static const Duration _staffCacheExpiry = Duration(hours: 6);
  static const Duration _charactersCacheExpiry = Duration(hours: 6);
  
  /// 根据动漫名称搜索Bangumi ID
  Future<int?> searchBangumiId(String animeName) async {
    final cacheKey = animeName.hashCode;
    
    // 检查缓存
    if (_bangumiIdCache.containsKey(cacheKey)) {
      final cached = _bangumiIdCache[cacheKey]!;
      if (!cached.isExpired) {
        print('BangumiComment: 使用缓存的Bangumi ID: ${cached.data}');
        return cached.data;
      } else {
        _bangumiIdCache.remove(cacheKey);
      }
    }
    
    try {
      print('BangumiComment: 搜索动漫 "$animeName"');
      
      final response = await http.get(
        Uri.parse('$baseUrl/search/subject/${Uri.encodeComponent(animeName)}?type=2'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['list'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final bangumiId = results[0]['id'] as int;
          print('BangumiComment: 找到Bangumi ID: $bangumiId');
          
          // 缓存结果
          _bangumiIdCache[cacheKey] = _CacheItem(bangumiId, _idCacheExpiry);
          
          return bangumiId;
        }
      }
      
      print('BangumiComment: 未找到匹配的动漫');
      
      // 缓存空结果
      _bangumiIdCache[cacheKey] = _CacheItem(null, _idCacheExpiry);
      
      return null;
    } catch (e) {
      print('BangumiComment: 搜索失败 - $e');
      return null;
    }
  }
  
  /// 获取制作人员列表
  Future<List<BangumiStaff>> getStaff(int bangumiId) async {
    // 检查缓存
    if (_staffCache.containsKey(bangumiId)) {
      final cached = _staffCache[bangumiId]!;
      if (!cached.isExpired) {
        print('BangumiStaff: 使用缓存的制作人员数据 (${cached.data.length} 位)');
        return cached.data;
      } else {
        _staffCache.remove(bangumiId);
      }
    }
    
    try {
      print('BangumiStaff: 获取制作人员 (ID: $bangumiId)');
      
      final response = await http.get(
        Uri.parse('$baseUrl/v0/subjects/$bangumiId/persons'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          final staffList = <BangumiStaff>[];
          
          for (final item in data) {
            try {
              staffList.add(BangumiStaff.fromJson(item));
            } catch (e) {
              print('BangumiStaff: 解析人员失败 - $e');
            }
          }
          
          print('BangumiStaff: 成功获取 ${staffList.length} 位制作人员');
          
          // 缓存结果
          _staffCache[bangumiId] = _CacheItem(staffList, _staffCacheExpiry);
          
          return staffList;
        }
      }
      
      print('BangumiStaff: 获取制作人员失败 (状态码: ${response.statusCode})');
      return [];
    } catch (e) {
      print('BangumiStaff: 获取制作人员异常 - $e');
      return [];
    }
  }
  
  /// 根据动漫名称获取制作人员
  Future<List<BangumiStaff>> getStaffByName(String animeName) async {
    final bangumiId = await searchBangumiId(animeName);
    if (bangumiId == null) {
      return [];
    }
    return getStaff(bangumiId);
  }
  
  /// 获取角色列表
  Future<List<BangumiCharacter>> getCharacters(int bangumiId) async {
    // 检查缓存
    if (_charactersCache.containsKey(bangumiId)) {
      final cached = _charactersCache[bangumiId]!;
      if (!cached.isExpired) {
        print('BangumiCharacter: 使用缓存的角色数据 (${cached.data.length} 个)');
        return cached.data;
      } else {
        _charactersCache.remove(bangumiId);
      }
    }
    
    try {
      print('BangumiCharacter: 获取角色 (ID: $bangumiId)');
      
      final response = await http.get(
        Uri.parse('$baseUrl/v0/subjects/$bangumiId/characters'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          final characterList = <BangumiCharacter>[];
          
          for (final item in data) {
            try {
              characterList.add(BangumiCharacter.fromJson(item));
            } catch (e) {
              print('BangumiCharacter: 解析角色失败 - $e');
            }
          }
          
          print('BangumiCharacter: 成功获取 ${characterList.length} 个角色');
          
          // 缓存结果
          _charactersCache[bangumiId] = _CacheItem(characterList, _charactersCacheExpiry);
          
          return characterList;
        }
      }
      
      print('BangumiCharacter: 获取角色失败 (状态码: ${response.statusCode})');
      return [];
    } catch (e) {
      print('BangumiCharacter: 获取角色异常 - $e');
      return [];
    }
  }
  
  /// 根据动漫名称获取角色
  Future<List<BangumiCharacter>> getCharactersByName(String animeName) async {
    final bangumiId = await searchBangumiId(animeName);
    if (bangumiId == null) {
      return [];
    }
    return getCharacters(bangumiId);
  }
  
  /// 清理所有缓存
  static void clearAllCache() {
    _bangumiIdCache.clear();
    _staffCache.clear();
    _charactersCache.clear();
    print('BangumiCommentService: 所有缓存已清理');
  }
  
  /// 清理过期缓存
  static void clearExpiredCache() {
    _bangumiIdCache.removeWhere((key, item) => item.isExpired);
    _staffCache.removeWhere((key, item) => item.isExpired);
    _charactersCache.removeWhere((key, item) => item.isExpired);
    print('BangumiCommentService: 过期缓存已清理');
  }
  
  /// 获取缓存统计信息
  static Map<String, dynamic> getCacheStats() {
    return {
      'bangumiIdCache': _bangumiIdCache.length,
      'staffCache': _staffCache.length,
      'charactersCache': _charactersCache.length,
      'totalCacheItems': _bangumiIdCache.length + 
                         _staffCache.length + 
                         _charactersCache.length,
    };
  }
}
