import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/anime.dart';
import '../services/bangumi_calendar_service.dart';
import '../services/cache_manager.dart';
import '../widgets/skeleton_loader.dart';
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
  Timer? _switchDebounceTimer; // 切换防抖定时器

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
      final oldWeekday = _selectedWeekday;
      
      // 立即更新选中状态，让动画流畅执行
      setState(() {
        _selectedWeekday = weekday;
      });
      
      // 检查是否有缓存数据
      if (_cacheManager.isWeekdayCached(weekday)) {
        // 有缓存，立即显示
        setState(() {
          _isLoading = false;
          _error = null;
        });
      } else {
        // 无缓存，延迟一帧后再显示加载状态，避免闪烁
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _selectedWeekday == weekday) {
            setState(() {
              _isLoading = true;
            });
            _loadDayData(weekday);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    // 取消定时器
    _preloadTimer?.cancel();
    _batchLoadTimer?.cancel();
    _switchDebounceTimer?.cancel();
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildWeekdayNavigation(),
          ),
          
          // 内容区域 - 带切换动画
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                // 淡入淡出 + 轻微缩放效果
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              child: _isLoading
                  ? _buildLoadingView()
                  : _error != null
                      ? _buildErrorView()
                      : _buildSelectedDayContent(),
            ),
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
        borderRadius: BorderRadius.circular(12),
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
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected 
                                  ? const Color(0xFF008080)
                                  : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.grey),
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
          
          // 下划线指示器（带拉伸效果）
          Container(
            height: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 7;
                final indicatorWidth = itemWidth * 0.5;
                
                return Stack(
                  children: [
                    // 背景轨道
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                        ),
                      ),
                    ),
                    // 滑动指示器 - 使用自定义动画实现拉伸效果
                    _AnimatedIndicator(
                      selectedIndex: _selectedWeekday - 1,
                      itemWidth: itemWidth,
                      indicatorWidth: indicatorWidth,
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
      return Center(
        key: ValueKey('empty_$_selectedWeekday'),
        child: const Column(
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

  /// 构建加载视图（使用骨架屏）
  Widget _buildLoadingView() {
    return Padding(
      key: ValueKey('loading_$_selectedWeekday'),
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片骨架
                SkeletonLoader(
                  width: 100,
                  height: 140,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                // 信息骨架
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(
                        width: double.infinity,
                        height: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        width: 150,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        width: 100,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SkeletonLoader(
                            width: 60,
                            height: 24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          const SizedBox(width: 8),
                          SkeletonLoader(
                            width: 70,
                            height: 24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建错误视图
  Widget _buildErrorView() {
    return Center(
      key: ValueKey('error_$_selectedWeekday'),
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
                return Material(
                  color: Colors.transparent,
                  child: AnimatedBuilder(
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
                                    // 大图缓存配置
                                    memCacheWidth: 400,
                                    memCacheHeight: 600,
                                    maxWidthDiskCache: 800,
                                    maxHeightDiskCache: 1200,
                                    fadeInDuration: const Duration(milliseconds: 0),
                                    fadeOutDuration: const Duration(milliseconds: 0),
                                    placeholderFadeInDuration: const Duration(milliseconds: 0),
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.grey[600],
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 80,
                    height: 110,
                    child: anime.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: anime.imageUrl,
                            fit: BoxFit.cover,
                            // 启用内存和磁盘缓存
                            memCacheWidth: 200,
                            memCacheHeight: 280,
                            maxWidthDiskCache: 400,
                            maxHeightDiskCache: 560,
                            // 禁用淡入动画，避免Hero动画白闪
                            fadeInDuration: const Duration(milliseconds: 0),
                            fadeOutDuration: const Duration(milliseconds: 0),
                            placeholderFadeInDuration: const Duration(milliseconds: 0),
                            // 加载中占位符
                            placeholder: (context, url) => const SkeletonLoader(
                              width: 80,
                              height: 110,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            // 错误占位符
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[600],
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image),
                          ),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rank ${anime.rank}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

/// 自定义拉伸动画指示器（模仿TabBar的拉伸效果）
class _AnimatedIndicator extends StatefulWidget {
  final int selectedIndex;
  final double itemWidth;
  final double indicatorWidth;

  const _AnimatedIndicator({
    required this.selectedIndex,
    required this.itemWidth,
    required this.indicatorWidth,
  });

  @override
  State<_AnimatedIndicator> createState() => _AnimatedIndicatorState();
}

class _AnimatedIndicatorState extends State<_AnimatedIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousIndex = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _currentIndex = widget.selectedIndex;
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(_AnimatedIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _currentIndex = widget.selectedIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = _animation.value;
        
        // 计算起始和结束位置
        final startCenter = widget.itemWidth * _previousIndex + widget.itemWidth / 2;
        final endCenter = widget.itemWidth * _currentIndex + widget.itemWidth / 2;
        
        // 拉伸效果：先拉伸到目标位置，然后收缩
        double left, right;
        
        if (progress < 0.5) {
          // 前半段：拉伸
          final stretchProgress = progress * 2;
          if (_currentIndex > _previousIndex) {
            // 向右移动
            left = startCenter - widget.indicatorWidth / 2;
            right = startCenter + widget.indicatorWidth / 2 + 
                    (endCenter - startCenter) * stretchProgress;
          } else {
            // 向左移动
            left = startCenter - widget.indicatorWidth / 2 - 
                   (startCenter - endCenter) * stretchProgress;
            right = startCenter + widget.indicatorWidth / 2;
          }
        } else {
          // 后半段：收缩
          final shrinkProgress = (progress - 0.5) * 2;
          if (_currentIndex > _previousIndex) {
            // 向右移动
            left = startCenter - widget.indicatorWidth / 2 + 
                   (endCenter - startCenter) * shrinkProgress;
            right = endCenter + widget.indicatorWidth / 2;
          } else {
            // 向左移动
            left = endCenter - widget.indicatorWidth / 2;
            right = startCenter + widget.indicatorWidth / 2 - 
                    (startCenter - endCenter) * shrinkProgress;
          }
        }
        
        return Positioned(
          bottom: 0,
          left: left,
          width: right - left,
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              color: Color(0xFF008080),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(1.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

