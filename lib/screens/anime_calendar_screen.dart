import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/anime.dart';
import '../services/bangumi_calendar_service.dart';
import '../services/cache_manager.dart';
import 'bangumi_anime_detail_screen.dart';

/// 番剧时间表页面
class AnimeCalendarScreen extends StatefulWidget {
  const AnimeCalendarScreen({super.key});

  @override
  State<AnimeCalendarScreen> createState() => _AnimeCalendarScreenState();
}

class _AnimeCalendarScreenState extends State<AnimeCalendarScreen> {
  final BangumiCalendarService _calendarService = BangumiCalendarService();
  final CacheManager _cacheManager = CacheManager();
  
  bool _isLoading = true;
  String? _error;
  int _selectedWeekday = DateTime.now().weekday; // 当前选中的星期
  
  // 预加载相关
  Timer? _preloadTimer;
  Timer? _batchLoadTimer;
  bool _isPreloading = false;
  Set<int> _loadingWeekdays = {}; // 正在加载的星期，防止重复加载

  @override
  void initState() {
    super.initState();
    _loadDayData(_selectedWeekday);
    _startPreloadStrategy();
  }

  /// 启动预加载策略
  void _startPreloadStrategy() {
    // 5秒后预加载当日数据（如果还没加载的话）
    _preloadTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _preloadCurrentDay();
      }
    });

    // 10秒后开始批量预加载其他星期
    _batchLoadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        _startBatchPreload();
      }
    });
  }

  /// 预加载当日数据
  void _preloadCurrentDay() {
    if (!_cacheManager.isWeekdayCached(_selectedWeekday)) {
      print('BangumiCalendar: 开始预加载当日数据...');
      _loadDayData(_selectedWeekday);
    } else {
      print('BangumiCalendar: 当日数据已存在，跳过预加载');
    }
  }

  /// 开始批量预加载
  void _startBatchPreload() {
    if (_isPreloading) return;
    
    _isPreloading = true;
    print('BangumiCalendar: 开始批量预加载策略...');
    
    // 获取需要预加载的星期列表（排除已加载的）
    final weekdaysToLoad = <int>[];
    for (int i = 1; i <= 7; i++) {
      if (!_cacheManager.isWeekdayCached(i)) {
        weekdaysToLoad.add(i);
      }
    }
    
    if (weekdaysToLoad.isEmpty) {
      print('BangumiCalendar: 所有数据已加载，无需预加载');
      _isPreloading = false;
      return;
    }
    
    _batchPreloadWeekdays(weekdaysToLoad);
  }

  /// 批量预加载星期数据（每次3个）
  void _batchPreloadWeekdays(List<int> weekdays) async {
    const batchSize = 3;
    
    for (int i = 0; i < weekdays.length; i += batchSize) {
      if (!mounted || !_isPreloading) break;
      
      final batch = weekdays.skip(i).take(batchSize).toList();
      print('BangumiCalendar: 预加载批次 ${(i ~/ batchSize) + 1}，星期: ${batch.join(', ')}');
      
      // 并发加载这一批次的数据
      final futures = batch.map((weekday) => _preloadDayData(weekday)).toList();
      await Future.wait(futures);
      
      // 批次间间隔2秒，避免API压力过大
      if (i + batchSize < weekdays.length) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    _isPreloading = false;
    print('BangumiCalendar: 批量预加载完成');
  }

  /// 预加载单天数据（静默加载，不影响UI）
  Future<void> _preloadDayData(int weekday) async {
    if (!mounted || _cacheManager.isWeekdayCached(weekday)) return;
    
    // 检查是否正在加载，防止重复请求
    if (_loadingWeekdays.contains(weekday)) {
      print('BangumiCalendar: 预加载跳过 - 星期$weekday 正在加载中');
      return;
    }
    
    _loadingWeekdays.add(weekday); // 标记为正在加载
    
    try {
      final dayAnime = await _calendarService.getDayCalendar(weekday);
      if (!mounted) {
        _loadingWeekdays.remove(weekday);
        return;
      }
      
      // 静默更新缓存，不触发UI重建
      _cacheManager.cacheWeekday(weekday, dayAnime);
      _loadingWeekdays.remove(weekday); // 移除加载标记
      
      print('BangumiCalendar: 预加载完成 - 星期$weekday，共${dayAnime.length}个番剧');
    } catch (e) {
      _loadingWeekdays.remove(weekday); // 移除加载标记
      print('BangumiCalendar: 预加载失败 - 星期$weekday: $e');
    }
  }

  /// 加载单天数据（带缓存）
  Future<void> _loadDayData(int weekday) async {
    if (!mounted) return;
    
    // 检查缓存
    if (_cacheManager.isWeekdayCached(weekday)) {
      print('BangumiCalendar: 使用缓存数据 - 星期$weekday');
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }
    
    // 检查是否正在加载，防止重复请求
    if (_loadingWeekdays.contains(weekday)) {
      print('BangumiCalendar: 星期$weekday 正在加载中，跳过重复请求');
      return;
    }
    
    _loadingWeekdays.add(weekday); // 标记为正在加载
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('BangumiCalendar: 开始加载星期$weekday 数据...');
      final dayAnime = await _calendarService.getDayCalendar(weekday);
      if (!mounted) {
        _loadingWeekdays.remove(weekday);
        return;
      }
      
      setState(() {
        _cacheManager.cacheWeekday(weekday, dayAnime); // 添加到缓存
        _isLoading = false;
      });
      
      _loadingWeekdays.remove(weekday); // 移除加载标记
      print('BangumiCalendar: 星期$weekday 数据加载完成，共${dayAnime.length}个番剧');
    } catch (e) {
      _loadingWeekdays.remove(weekday); // 移除加载标记
      if (!mounted) return;
      
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 切换星期并加载对应数据
  void _onWeekdayChanged(int weekday) {
    if (_selectedWeekday != weekday) {
      setState(() {
        _selectedWeekday = weekday;
      });
      _loadDayData(weekday);
    }
  }

  @override
  void dispose() {
    // 取消定时器
    _preloadTimer?.cancel();
    _batchLoadTimer?.cancel();
    _isPreloading = false;
    
    // 注意：这里不清理缓存，缓存应该在应用关闭时清理
    // 只清理加载状态，防止内存泄漏
    _loadingWeekdays.clear();
    
    print('BangumiCalendar: 页面销毁，保留缓存数据');
    super.dispose();
  }

  /// 清理缓存
  void _clearCache() {
    print('BangumiCalendar: 清理缓存数据...');
    _cacheManager.clearAllCache();
    _loadingWeekdays.clear(); // 清理加载状态
    print('BangumiCalendar: 缓存已清理');
  }

  /// 刷新当前星期数据
  void _refreshCurrentDay() {
    // 清除当前星期的缓存和加载状态
    _cacheManager.removeCachedWeekday(_selectedWeekday);
    _loadingWeekdays.remove(_selectedWeekday);
    // 重新加载
    _loadDayData(_selectedWeekday);
  }

  /// 清理所有缓存并重新加载当前星期
  void _clearAllCache() {
    // 停止预加载
    _preloadTimer?.cancel();
    _batchLoadTimer?.cancel();
    _isPreloading = false;
    
    _clearCache();
    _loadDayData(_selectedWeekday);
    
    // 重新启动预加载策略
    _startPreloadStrategy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 头部标题栏
          _buildHeader(),
          
          // 星期导航栏
          _buildWeekdayNavigation(),
          
          // 内容区域
          Expanded(
            child: _isLoading
                ? _buildLoadingView()
                : _error != null
                    ? _buildErrorView()
                    : _buildSelectedDayContent(),
          ),
        ],
      ),
    );
  }

  /// 构建头部标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 标题
          Row(
            children: [
              Icon(
                Icons.calendar_view_week,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '番剧周时间表',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // 刷新按钮
          IconButton(
            onPressed: _refreshCurrentDay,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新当前星期',
          ),
          
          // 清理缓存按钮
          IconButton(
            onPressed: _clearAllCache,
            icon: const Icon(Icons.clear_all),
            tooltip: '清理所有缓存',
          ),
        ],
      ),
    );
  }

  /// 构建星期导航栏
  Widget _buildWeekdayNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 星期按钮行
          Container(
            height: 50,
            child: Row(
              children: List.generate(7, (index) {
                final weekday = index + 1;
                final isSelected = weekday == _selectedWeekday;
                final dayName = BangumiCalendarService.getWeekdayName(weekday);
                final shortName = dayName.replaceAll('星期', '');
                
                return Expanded(
                  child: InkWell(
                    onTap: () => _onWeekdayChanged(weekday),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            shortName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // 滑动指示器
          Container(
            height: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 7;
                return Stack(
                  children: [
                    // 背景轨道
                    Container(
                      width: double.infinity,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    // 滑动指示器
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      left: itemWidth * (_selectedWeekday - 1) + (itemWidth - 24) / 2,
                      child: Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF40E0D0),
                          borderRadius: BorderRadius.circular(1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF40E0D0).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 构建选中日期的内容
  Widget _buildSelectedDayContent() {
    final selectedDayAnime = _cacheManager.getCachedWeekday(_selectedWeekday) ?? [];
    
    if (selectedDayAnime.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '今日无更新',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '暂无番剧更新计划',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(_selectedWeekday), // 添加key避免不必要的重建
      padding: const EdgeInsets.all(16),
      itemCount: selectedDayAnime.length,
      itemBuilder: (context, index) {
        return _buildAnimeListItem(selectedDayAnime[index]);
      },
    );
  }

  /// 构建加载视图
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载番剧时间表...'),
        ],
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? '加载失败',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshCurrentDay,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }



  /// 构建番剧列表项
  Widget _buildAnimeListItem(Anime anime) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: Theme.of(context).primaryColor.withOpacity(0.1),
          highlightColor: Theme.of(context).primaryColor.withOpacity(0.05),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  BangumiAnimeDetailScreen(anime: anime),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                // 添加淡入和轻微缩放动画
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.95,
                      end: 1.0,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
              reverseTransitionDuration: const Duration(milliseconds: 300),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 封面图片 - 添加Hero动画
            Hero(
              tag: 'anime_image_${anime.id}',
              createRectTween: (begin, end) {
                return RectTween(begin: begin, end: end);
              },
              flightShuttleBuilder: (
                BuildContext flightContext,
                Animation<double> animation,
                HeroFlightDirection flightDirection,
                BuildContext fromHeroContext,
                BuildContext toHeroContext,
              ) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (animation.value * 0.1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          10 + (animation.value * 2), // 圆角在动画中稍微变化
                        ),
                        child: SizedBox(
                          width: 80 + (animation.value * 80), // 宽度从80变到160
                          height: 110 + (animation.value * 130), // 高度从110变到240
                          child: anime.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: anime.imageUrl,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 110,
                  child: anime.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image),
                        ),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和排名
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          anime.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (anime.rank != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Rank ${anime.rank}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 简介
                  if (anime.description.isNotEmpty)
                    Text(
                      anime.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // 标签
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: anime.tags.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF40E0D0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF40E0D0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
        ),
      ),
    );
  }

}
