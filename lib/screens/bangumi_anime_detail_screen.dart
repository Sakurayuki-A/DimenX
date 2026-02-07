import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../providers/favorites_provider.dart';
import '../providers/source_rule_provider.dart';
import '../services/anime_search_service.dart';
import '../services/anime_detail_service.dart';
import '../services/bangumi_api_service.dart';
import '../widgets/source_selection_sidebar.dart';
import '../widgets/bangumi_comments_section.dart';
import '../widgets/skeleton_loader.dart';
import 'anime_detail_screen.dart';
import 'optimized_video_player_screen.dart';
import 'dart:ui';

/// Bangumi动漫详情页面
class BangumiAnimeDetailScreen extends StatefulWidget {
  final Anime anime;
  const BangumiAnimeDetailScreen({
    super.key,
    required this.anime,
  });

  @override
  State<BangumiAnimeDetailScreen> createState() => _BangumiAnimeDetailScreenState();
}

class _BangumiAnimeDetailScreenState extends State<BangumiAnimeDetailScreen> 
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isLoadingDetails = false;
  String _error = '';
  Anime? _detailedAnime;
  final BangumiApiService _bangumiService = BangumiApiService();
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));
    _loadDetailedInfo();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  /// 加载详细信息（优化版：快速响应）
  Future<void> _loadDetailedInfo() async {
    // 判断是否需要加载详细信息
    final needsDetailedInfo = widget.anime.source == 'Bangumi' && 
        (widget.anime.id.contains('calendar') ||
         widget.anime.description == '暂无简介' || 
         widget.anime.description.isEmpty ||
         widget.anime.description.length < 50 ||  // 简介太短
         widget.anime.description.contains('年') && widget.anime.description.contains('话') ||
         widget.anime.tags.isEmpty ||  // 没有标签
         widget.anime.tags.length < 3);  // 标签太少
    
    if (needsDetailedInfo) {
      setState(() {
        _isLoadingDetails = true;
      });
      _loadingController.repeat();
      
      // 提取Bangumi ID，支持多种格式
      String bangumiId = widget.anime.id;
      if (bangumiId.startsWith('bangumi_calendar_')) {
        bangumiId = bangumiId.replaceFirst('bangumi_calendar_', '');
      } else if (bangumiId.startsWith('bangumi_')) {
        bangumiId = bangumiId.replaceFirst('bangumi_', '');
      }
      print('⚡ 快速获取Bangumi详细信息: $bangumiId');
      
      final startTime = DateTime.now();
      
      try {
        // 设置最大等待时间为3秒，超时则显示基本信息
        final detailedAnime = await _bangumiService.getAnimeDetail(bangumiId)
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                print('⚠️ 详情加载超时，使用基本信息');
                return null;
              },
            );
        
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        
        if (detailedAnime != null && mounted) {
          setState(() {
            _detailedAnime = detailedAnime;
            _isLoadingDetails = false;
          });
          _loadingController.stop();
          print('✓ 成功获取详细信息，耗时: ${elapsed}ms');
          print('  - 简介长度: ${detailedAnime.description.length}');
          print('  - 标签数量: ${detailedAnime.tags.length}');
        } else if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
          _loadingController.stop();
          print('⚠️ 未获取到详细信息，耗时: ${elapsed}ms');
        }
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        print('✗ 获取详细信息失败，耗时: ${elapsed}ms，错误: $e');
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
          _loadingController.stop();
        }
      }
    }
  }

  /// 获取当前显示的动漫信息（优先使用详细信息）
  Anime get currentAnime => _detailedAnime ?? widget.anime;
  
  /// 获取稳定的图片URL（避免重新加载）
  String get stableImageUrl {
    // 优先使用原始图片URL，避免重新加载
    if (widget.anime.imageUrl.isNotEmpty) {
      return widget.anime.imageUrl;
    }
    // 如果原始图片为空，才使用详细信息中的图片
    return currentAnime.imageUrl;
  }

  /// 构建加载指示器（使用骨架屏）
  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 多行文本骨架
          ...List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SkeletonLoader(
                width: double.infinity,
                height: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
          // 最后一行短一些
          SkeletonLoader(
            width: 200,
            height: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  /// 构建标签加载指示器（使用骨架屏）
  Widget _buildTagsLoadingIndicator() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(3, (index) {
        return SkeletonLoader(
          width: 60 + (index * 10.0),
          height: 24,
          borderRadius: BorderRadius.circular(6),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentAnime.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: const [],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 上半部分 - 带模糊背景
              Container(
                height: 280,
                child: Stack(
                  children: [
                    // 模糊背景 - 使用缓存图片
                    Positioned.fill(
                      child: stableImageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: stableImageUrl,
                              fit: BoxFit.cover,
                              // 使用相同的缓存配置
                              memCacheWidth: 800,
                              memCacheHeight: 1200,
                              // 加载时显示灰色背景
                              placeholder: (context, url) => Container(
                                color: Colors.grey[800],
                              ),
                              // 错误时显示灰色背景
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[800],
                              ),
                              // 快速淡入，避免闪烁
                              fadeInDuration: const Duration(milliseconds: 150),
                              fadeOutDuration: const Duration(milliseconds: 50),
                            )
                          : Container(color: Colors.grey[800]),
                    ),
                    // 模糊效果（增强模糊）
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                    // 内容
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildAnimeInfoCard(),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 下半部分 - 标签页内容
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BangumiCommentsSection(
                    animeName: widget.anime.title,
                    animeDescription: currentAnime.description,
                    tags: currentAnime.tags,
                  ),
                ),
              ),
            ],
          ),
          
          // 浮动播放按钮
          _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildAnimeInfoCard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 封面图片（带阴影）
        Hero(
          tag: 'anime_image_${widget.anime.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 160,
                  height: 240,
                  child: stableImageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: stableImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SkeletonLoader(
                            width: 160,
                            height: 240,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          errorWidget: (context, url, error) => _buildPlaceholderImage(),
                          fadeInDuration: const Duration(milliseconds: 0),
                          fadeOutDuration: const Duration(milliseconds: 0),
                          placeholderFadeInDuration: const Duration(milliseconds: 0),
                        )
                      : _buildPlaceholderImage(),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 20),
        
        // 动漫信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                currentAnime.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 10),
              
              // 评分、排名、年月信息 - 紧凑布局
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  // 评分
                  if (currentAnime.rating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB800),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currentAnime.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 排名
                  if (currentAnime.rank != null && currentAnime.rank! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFFF6B6B),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#${currentAnime.rank}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // 年月信息
                  if (_getYearMonth(currentAnime).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF4ECDC4),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getYearMonth(currentAnime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // 标签
              if (_isLoadingDetails)
                _buildTagsLoadingIndicator()
              else if (currentAnime.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: currentAnime.tags.take(5).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                // 没有标签时显示占位
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '暂无标签',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              // 收藏按钮
              Consumer<FavoritesProvider>(
                builder: (context, favoritesProvider, child) {
                  final isFavorited = favoritesProvider.isFavorite(widget.anime.id);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOutCubic,
                      height: 44,
                      constraints: BoxConstraints(
                        minWidth: 44,
                        maxWidth: isFavorited ? 120 : 44,
                      ),
                      decoration: BoxDecoration(
                        color: isFavorited 
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor)
                            : Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(isFavorited ? 8 : 22),
                        boxShadow: isFavorited ? [
                          BoxShadow(
                            color: (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ] : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(isFavorited ? 8 : 22),
                          onTap: () async {
                            // 触觉反馈
                            HapticFeedback.lightImpact();
                            
                            await favoritesProvider.toggleFavorite(widget.anime);
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isFavorited ? Icons.heart_broken : Icons.favorite,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(isFavorited ? '已取消收藏' : '已添加到收藏'),
                                    ],
                                  ),
                                  duration: const Duration(milliseconds: 1500),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SizeTransition(
                                      sizeFactor: animation,
                                      axis: Axis.horizontal,
                                      child: child,
                                    ),
                                  );
                                },
                                child: isFavorited
                                    ? Row(
                                        key: const ValueKey('favorited'),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.favorite,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '已收藏',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(
                                        key: const ValueKey('not_favorited'),
                                        Icons.favorite_border,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: _isLoading ? null : _handlePlayButtonPressed,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF008080)
            : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.play_arrow, size: 32),
      ),
    );
  }

  Widget _buildDetailInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '简介',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF008080)
                    : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            _isLoadingDetails 
                ? _buildLoadingIndicator()
                : Text(
                    currentAnime.description.isNotEmpty 
                        ? currentAnime.description 
                        : '暂无简介信息',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
            
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[700]!, Colors.grey[900]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie, color: Colors.grey[400], size: 40),
          const SizedBox(height: 8),
          Text(
            '暂无封面',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    return Colors.grey;
  }
  
  /// 获取年月信息
  String _getYearMonth(Anime anime) {
    if (anime.airDate.isEmpty) {
      return anime.year > 0 ? '${anime.year}年' : '';
    }
    
    final date = DateTime.tryParse(anime.airDate);
    if (date != null) {
      return '${date.year}年${date.month}月';
    }
    
    // 尝试匹配 YYYY-MM 格式
    final regex = RegExp(r'(\d{4})-(\d{1,2})');
    final match = regex.firstMatch(anime.airDate);
    if (match != null) {
      final year = match.group(1);
      final month = match.group(2);
      return '$year年$month月';
    }
    
    return anime.year > 0 ? '${anime.year}年' : '';
  }

  Future<void> _handlePlayButtonPressed() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 获取可用的播放源规则
      final sourceRuleProvider = context.read<SourceRuleProvider>();
      final availableSources = sourceRuleProvider.rules;

      if (availableSources.isEmpty) {
        setState(() {
          _error = '暂无可用播放源，请在设置中添加播放源规则';
          _isLoading = false;
        });
        return;
      }

      // 显示播放源选择对话框
      if (mounted) {
        showSourceSelectionSidebar(
          context,
          anime: widget.anime,
          availableSources: availableSources,
          onSourceSelected: _handleSourceSelected,
        );
      }
    } catch (e) {
      setState(() {
        _error = '获取播放源失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSourceSelected(SourceRule sourceRule, {String? customQuery, Anime? selectedAnime}) async {
    try {
      // 侧边栏已经在内部关闭了，等待确保完全关闭
      await Future.delayed(const Duration(milliseconds: 350));
      
      Anime targetAnime;
      
      // 如果已经提供了选中的anime对象，直接使用
      if (selectedAnime != null) {
        targetAnime = selectedAnime;
      } else {
        // 否则需要搜索
        final searchService = AnimeSearchService();
        final searchQuery = customQuery ?? widget.anime.title;
        
        final searchResults = await searchService.searchAnimes(
          searchQuery, 
          [sourceRule]
        );

        if (searchResults.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('在 ${sourceRule.name} 中未找到该动漫'),
                backgroundColor: Colors.grey,
              ),
            );
          }
          return;
        }

        targetAnime = searchResults.first;
      }

      // 获取集数信息
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在获取集数信息...'),
              ],
            ),
          ),
        );
      }

      // 获取详细信息（包括集数列表）
      final detailService = AnimeDetailService();
      final detailedAnime = await detailService.fetchAnimeDetail(targetAnime, sourceRule);
      
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 检查是否有集数
      if (detailedAnime.episodeList == null || detailedAnime.episodeList!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未找到可播放的集数'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 跳转到播放器（不指定集数，让用户选择）
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OptimizedVideoPlayerScreen(
              anime: detailedAnime,
              episodeNumber: 0, // 0 表示未选择集数
              sourceRule: sourceRule,
            ),
          ),
        );
      }
    } catch (e) {
      print('播放源处理失败: $e');
      
      // 关闭可能存在的加载对话框
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
