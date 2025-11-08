import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime.dart';
/// Bangumi番剧时间表服务
class BangumiCalendarService {
  static const String _baseUrl = 'https://api.bgm.tv';
  
  /// 获取单天的番剧数据
  Future<List<Anime>> getDayCalendar(int weekday) async {
    try {
      // 使用Bangumi的calendar接口
      final response = await http.get(
        Uri.parse('$_baseUrl/calendar'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0.0 (https://github.com/your-repo)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return await _parseDayData(data, weekday);
      } else {
        print('BangumiCalendar: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('BangumiCalendar: 获取时间表失败: $e');
      return [];
    }
  }

  /// 获取指定年份和季度的番剧时间表
  Future<Map<int, List<Anime>>> getCalendar({
    int? year,
    int? month,
  }) async {
    try {
      // 使用Bangumi的calendar接口
      final response = await http.get(
        Uri.parse('$_baseUrl/calendar'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0.0 (https://github.com/your-repo)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return await _parseCalendarData(data, year: year, month: month);
      } else {
        print('BangumiCalendar: HTTP ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('BangumiCalendar: 获取时间表失败: $e');
      return {};
    }
  }

  /// 解析单天数据
  Future<List<Anime>> _parseDayData(List<dynamic> data, int targetWeekday) async {
    try {
      // 找到对应星期的数据
      for (int i = 0; i < data.length; i++) {
        final dayData = data[i];
        final weekday = dayData['weekday']?['id'] ?? (i + 1);
        
        if (weekday == targetWeekday) {
          final items = dayData['items'] as List<dynamic>? ?? [];
          final dayAnime = <Anime>[];
          
          // 限制并发请求数量，避免API限制
          final futures = <Future<Anime?>>[];
          for (final item in items.take(10)) { // 限制最多10个番剧获取详情
            futures.add(_parseAnimeFromCalendar(item));
          }
          
          final results = await Future.wait(futures);
          for (final anime in results) {
            if (anime != null) {
              dayAnime.add(anime);
            }
          }
          
          // 按评分排序
          dayAnime.sort((a, b) => b.rating.compareTo(a.rating));
          return dayAnime;
        }
      }
      
      return [];
    } catch (e) {
      print('BangumiCalendar: 解析单天数据失败: $e');
      return [];
    }
  }

  /// 解析时间表数据
  Future<Map<int, List<Anime>>> _parseCalendarData(List<dynamic> data, {int? year, int? month}) async {
    final calendar = <int, List<Anime>>{};
    
    try {
      for (int i = 0; i < data.length; i++) {
        final dayData = data[i];
        final weekday = dayData['weekday']?['id'] ?? (i + 1);
        final items = dayData['items'] as List<dynamic>? ?? [];
        
        final dayAnime = <Anime>[];
        
        // 限制并发请求数量，避免API限制
        final futures = <Future<Anime?>>[];
        for (final item in items.take(10)) { // 限制每天最多10个番剧获取详情
          futures.add(_parseAnimeFromCalendar(item, year: year, month: month));
        }
        
        final results = await Future.wait(futures);
        for (final anime in results) {
          if (anime != null) {
            dayAnime.add(anime);
          }
        }
        
        // 按评分排序
        dayAnime.sort((a, b) => b.rating.compareTo(a.rating));
        calendar[weekday] = dayAnime;
      }
      
      print('BangumiCalendar: 解析完成，共 ${calendar.length} 天的数据');
      return calendar;
    } catch (e) {
      print('BangumiCalendar: 解析时间表数据失败: $e');
      return {};
    }
  }

  /// 解析单个番剧数据
  Future<Anime?> _parseAnimeFromCalendar(Map<String, dynamic> item, {int? year, int? month}) async {
    try {
      final id = item['id']?.toString() ?? '';
      final name = item['name'] ?? '';
      final nameCn = item['name_cn'] ?? '';
      final airDate = item['air_date'] ?? '';
      final eps = item['eps'] ?? 0;
      final rating = (item['rating']?['score'] as num?)?.toDouble() ?? 0.0;
      final ratingCount = item['rating']?['total'] ?? 0;
      
      // 获取详细信息（年月日、集数、作者、工作室）
      Map<String, dynamic> detailInfo = {};
      try {
        detailInfo = await _getAnimeDetail(id);
      } catch (e) {
        print('BangumiCalendar: 获取番剧 $id 详情失败: $e');
        detailInfo = {};
      }
      
      // 过滤条件
      if (year != null && month != null) {
        if (!_isInTargetPeriod(airDate, year, month)) {
          return null;
        }
      }
      
      // 获取图片URL
      String imageUrl = '';
      final images = item['images'];
      if (images != null) {
        imageUrl = images['large'] ?? images['medium'] ?? images['small'] ?? '';
      }
      
      // 获取标签
      final tags = <String>[];
      if (rating > 0) {
        tags.add('★ ${rating.toStringAsFixed(1)}');
      }
      if (ratingCount > 0) {
        tags.add('${ratingCount}人评分');
      }
      if (eps > 0) {
        tags.add('${eps}话');
      }
      
      // 获取类型信息
      final genres = <String>[];
      final type = item['type']?.toString() ?? '';
      if (type.isNotEmpty) {
        genres.add(type);
      }
      
      return Anime(
        id: 'bangumi_calendar_$id',
        title: nameCn.isNotEmpty ? nameCn : name,
        imageUrl: imageUrl,
        detailUrl: 'https://bgm.tv/subject/$id',
        description: _generateSimpleDescription(detailInfo, airDate, eps),
        tags: tags,
        genres: genres,
        rating: rating,
        year: _extractYearFromDate(airDate),
        status: _getStatusFromAirDate(airDate),
        episodeCount: eps,
        episodes: eps,
        source: 'Bangumi',
        rank: item['rank'], // 添加排名信息
      );
    } catch (e) {
      print('BangumiCalendar: 解析番剧数据失败: $e');
      return null;
    }
  }

  /// 获取番剧详细信息
  Future<Map<String, dynamic>> _getAnimeDetail(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/v0/subjects/$id'),
        headers: {
          'User-Agent': 'AnimeHUBX/1.0.0 (https://github.com/your-repo)',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'date': data['date'] ?? '',
          'eps': data['eps'] ?? 0,
          'staff': _extractStaff(data['infobox'] ?? []),
          'studio': _extractStudio(data['infobox'] ?? []),
        };
      } else {
        return {};
      }
    } catch (e) {
      print('BangumiCalendar: 获取番剧详情失败: $e');
      return {};
    }
  }

  /// 提取制作人员信息
  String _extractStaff(List<dynamic> infobox) {
    final staffList = <String>[];
    for (final item in infobox) {
      if (item['key'] == '导演' || item['key'] == '原作' || item['key'] == '脚本') {
        final value = item['value'];
        if (value is String && value.isNotEmpty) {
          staffList.add('${item['key']}：$value');
        } else if (value is List && value.isNotEmpty) {
          final names = value.map((v) => v['name'] ?? v.toString()).join('、');
          staffList.add('${item['key']}：$names');
        }
      }
    }
    return staffList.take(2).join('，'); // 最多显示2个
  }

  /// 提取制作工作室信息
  String _extractStudio(List<dynamic> infobox) {
    for (final item in infobox) {
      if (item['key'] == '动画制作' || item['key'] == '制作') {
        final value = item['value'];
        if (value is String && value.isNotEmpty) {
          return value;
        } else if (value is List && value.isNotEmpty) {
          return value.map((v) => v['name'] ?? v.toString()).join('、');
        }
      }
    }
    return '';
  }

  /// 生成简洁描述（年月日、集数、作者、工作室）
  String _generateSimpleDescription(Map<String, dynamic> detailInfo, String airDate, int eps) {
    final parts = <String>[];
    
    // 播出日期
    final date = detailInfo['date'] ?? airDate;
    if (date.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(date);
        parts.add('${dateTime.year}年${dateTime.month}月${dateTime.day}日');
      } catch (e) {
        if (date.length >= 4) {
          parts.add('${date.substring(0, 4)}年');
        }
      }
    }
    
    // 集数
    final episodes = detailInfo['eps'] ?? eps;
    if (episodes > 0) {
      parts.add('共${episodes}话');
    }
    
    // 制作人员
    final staff = detailInfo['staff'] ?? '';
    if (staff.isNotEmpty) {
      parts.add(staff);
    }
    
    // 制作工作室
    final studio = detailInfo['studio'] ?? '';
    if (studio.isNotEmpty) {
      parts.add('制作：$studio');
    }
    
    return parts.isNotEmpty ? parts.join('，') : '暂无详细信息';
  }


  /// 检查是否在目标时间段内
  bool _isInTargetPeriod(String airDate, int year, int month) {
    if (airDate.isEmpty) return true;
    
    try {
      final date = DateTime.parse(airDate);
      return date.year == year && date.month == month;
    } catch (e) {
      return true; // 解析失败时包含
    }
  }


  /// 从日期字符串提取年份
  int _extractYearFromDate(String dateStr) {
    if (dateStr.isEmpty) return DateTime.now().year;
    
    try {
      final date = DateTime.parse(dateStr);
      return date.year;
    } catch (e) {
      // 尝试提取年份数字
      final yearMatch = RegExp(r'(\d{4})').firstMatch(dateStr);
      if (yearMatch != null) {
        return int.parse(yearMatch.group(1)!);
      }
      return DateTime.now().year;
    }
  }

  /// 根据播出日期获取状态
  String _getStatusFromAirDate(String airDate) {
    if (airDate.isEmpty) return '未知';
    
    try {
      final date = DateTime.parse(airDate);
      final now = DateTime.now();
      
      if (date.isAfter(now)) {
        return '未播出';
      } else if (date.year == now.year && date.month == now.month) {
        return '正在播出';
      } else {
        return '已完结';
      }
    } catch (e) {
      return '未知';
    }
  }


  /// 获取星期名称
  static String getWeekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return '星期一';
      case 2:
        return '星期二';
      case 3:
        return '星期三';
      case 4:
        return '星期四';
      case 5:
        return '星期五';
      case 6:
        return '星期六';
      case 7:
        return '星期日';
      default:
        return '未知';
    }
  }
}
