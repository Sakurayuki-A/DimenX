import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../providers/favorites_provider.dart';
import '../providers/source_rule_provider.dart';
import '../services/anime_search_service.dart';
import '../services/bangumi_api_service.dart';
import '../widgets/source_selection_sidebar.dart';
import 'anime_detail_screen.dart';
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

  /// 加载详细信息
  Future<void> _loadDetailedInfo() async {
    // 如果是Bangumi来源且来自时间表（ID包含calendar），需要获取完整详细信息
    if (widget.anime.source == 'Bangumi' && 
        (widget.anime.id.contains('calendar') ||
         widget.anime.description == '暂无简介' || 
         widget.anime.description.isEmpty ||
         widget.anime.description.contains('年') && widget.anime.description.contains('话') ||
         widget.anime.tags.length < 5)) {
      
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
      print('获取Bangumi详细信息: $bangumiId (原ID: ${widget.anime.id})');
      
      try {
        final detailedAnime = await _bangumiService.getAnimeDetail(bangumiId);
        if (detailedAnime != null && mounted) {
          setState(() {
            _detailedAnime = detailedAnime;
            _isLoadingDetails = false;
          });
          _loadingController.stop();
          print('成功获取详细信息: ${detailedAnime.title}');
          print('详细简介长度: ${detailedAnime.description.length}');
          print('标签数量: ${detailedAnime.tags.length}');
          print('原始图片URL: ${widget.anime.imageUrl}');
          print('详细图片URL: ${detailedAnime.imageUrl}');
          print('使用稳定图片URL: $stableImageUrl');
        } else if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
          _loadingController.stop();
        }
      } catch (e) {
        print('获取详细信息失败: $e');
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

  /// 构建加载指示器
  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 脉冲动画的圆形指示器
              Transform.scale(
                scale: 0.8 + (_loadingAnimation.value * 0.4),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF008080).withOpacity(0.3 + _loadingAnimation.value * 0.4)
                        : Theme.of(context).primaryColor.withOpacity(0.3 + _loadingAnimation.value * 0.4),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 加载文字
              Text(
                '正在获取详细信息...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              // 骨架屏效果
              ...List.generate(3, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey[300]!.withOpacity(0.3),
                        Colors.grey[100]!.withOpacity(0.8),
                        Colors.grey[300]!.withOpacity(0.3),
                      ],
                      stops: [
                        0.0,
                        _loadingAnimation.value,
                        1.0,
                      ],
                    ),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  /// 构建标签加载指示器
  Widget _buildTagsLoadingIndicator() {
    return AnimatedBuilder(
      animation: _loadingAnimation,
      builder: (context, child) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(3, (index) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[400]!.withOpacity(0.3),
                    Colors.grey[200]!.withOpacity(0.6),
                    Colors.grey[400]!.withOpacity(0.3),
                  ],
                  stops: [
                    0.0,
                    _loadingAnimation.value,
                    1.0,
                  ],
                ),
              ),
              child: Text(
                '加载中...',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            );
          }),
        );
      },
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
                    // 模糊背景
                    Positioned.fill(
                      child: widget.anime.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.anime.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(color: Colors.grey[800]);
                              },
                            )
                          : Container(color: Colors.grey[800]),
                    ),
                    // 模糊效果
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
              
              // 下半部分 - 正常内容
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 动漫详细信息
                      _buildDetailInfo(),
                    ],
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
        // 封面图片
        Hero(
          tag: 'anime_image_${widget.anime.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 160,
              height: 240,
              child: stableImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: stableImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholderImage(),
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 100),
                    )
                  : _buildPlaceholderImage(),
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
              
              const SizedBox(height: 12),
              
              // 评分和年份
              Row(
                children: [
                  if (currentAnime.rating > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(5, (index) {
                            double rating = currentAnime.rating / 2; // 将10分制转换为5分制
                            if (index < rating.floor()) {
                              // 完整星星
                              return const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 16,
                              );
                            } else if (index < rating) {
                              // 半星
                              return const Icon(
                                Icons.star_half_rounded,
                                color: Colors.white,
                                size: 16,
                              );
                            } else {
                              // 空星
                              return const Icon(
                                Icons.star_outline_rounded,
                                color: Colors.white,
                                size: 16,
                              );
                            }
                          }),
                          const SizedBox(width: 6),
                          Text(
                            currentAnime.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${currentAnime.year}年',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 状态
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentAnime.status,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 标签
              if (_isLoadingDetails)
                _buildTagsLoadingIndicator()
              else if (currentAnime.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: currentAnime.tags.take(3).map((tag) {
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

  Future<void> _handleSourceSelected(SourceRule sourceRule, {String? customQuery}) async {
    try {
      print('用户选择播放源: ${sourceRule.name}');
      
      // 使用选定的播放源搜索动漫
      final searchService = AnimeSearchService();
      final searchQuery = customQuery ?? widget.anime.title;
      print('搜索关键词: $searchQuery');
      
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

      // 选择最匹配的结果（通常是第一个）
      final selectedAnime = searchResults.first;
      
      print('找到匹配动漫: ${selectedAnime.title}');

      // 跳转到动漫详情页面（显示集数）
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailScreen(
              anime: selectedAnime,
              sourceRule: sourceRule,
            ),
          ),
        );
      }
    } catch (e) {
      print('播放源搜索失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }
}
