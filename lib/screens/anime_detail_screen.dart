import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../services/anime_detail_service.dart';
import '../widgets/skeleton_loader.dart';
import '../screens/optimized_video_player_screen.dart';

class AnimeDetailScreen extends StatefulWidget {
  final Anime anime;
  final SourceRule? sourceRule;
  const AnimeDetailScreen({
    super.key,
    required this.anime,
    this.sourceRule,
  });

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  Anime? _detailedAnime;
  bool _isLoading = true;
  bool _isSelectingRoad = false; // 是否正在选择路线
  String? _selectedRoadXPath; // 当前选择的路线 XPath
  
  @override
  void initState() {
    super.initState();
    _detailedAnime = widget.anime;
    
    // 添加到观看历史
    Future.microtask(() {
      if (mounted) {
        context.read<HistoryProvider>().addToHistory(widget.anime);
      }
    });
    
    // 检查是否需要路线选择
    if (widget.sourceRule != null &&
        widget.sourceRule!.roadList.isNotEmpty && 
        widget.sourceRule!.roadName.isNotEmpty) {
      // 需要路线选择
      _isSelectingRoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectRoadAndFetchDetail();
        }
      });
    } else {
      // 不需要路线选择，直接获取详情
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchAnimeDetail();
        }
      });
    }
  }
  
  // 选择路线并获取详情
  Future<void> _selectRoadAndFetchDetail() async {
    await _selectRoad();
    
    // 如果用户没有取消选择，继续获取详情
    if (mounted) {
      setState(() {
        _isSelectingRoad = false;
      });
      await _fetchAnimeDetail();
    }
  }
  
  // 选择路线
  Future<void> _selectRoad() async {
    try {
      final detailService = AnimeDetailService();
      final roads = await detailService.extractRoads(
        widget.anime.detailUrl,
        widget.sourceRule!,
      );
      
      if (roads.isNotEmpty) {
        // 显示路线选择对话框
        final selectedRoadIndex = await _showRoadSelectionDialog(roads);
        
        if (selectedRoadIndex == null) {
          // 用户取消了选择，返回上一页
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
        
        // 保存选择的路线索引
        setState(() {
          _selectedRoadXPath = selectedRoadIndex.toString();
        });
      }
    } catch (e) {
      print('提取路线失败: $e');
    }
  }
  
  Future<void> _fetchAnimeDetail() async {
    try {
      final detailService = AnimeDetailService();
      
      // 如果用户选择了路线索引，传递给详情服务
      int? roadIndex;
      if (_selectedRoadXPath != null) {
        roadIndex = int.tryParse(_selectedRoadXPath!);
      }
      
      final detailedAnime = await detailService.fetchAnimeDetailWithRoad(
        widget.anime,
        widget.sourceRule!,
        roadIndex: roadIndex,
      );
      
      if (mounted) {
        setState(() {
          _detailedAnime = detailedAnime;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('获取详情失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 显示路线选择对话框
  Future<int?> _showRoadSelectionDialog(List<String> roads) async {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择播放路线'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: roads.asMap().entries.map((entry) {
              final index = entry.key;
              final roadName = entry.value;
              return ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(roadName),
                onTap: () {
                  Navigator.pop(context, index);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 播放集数
  Future<void> _playEpisode(int episodeNumber) async {
    // 使用已选择的路线（如果有）
    SourceRule? effectiveRule = widget.sourceRule;
    if (_selectedRoadXPath != null && widget.sourceRule != null) {
      effectiveRule = widget.sourceRule!.copyWith(
        chapterRoads: _selectedRoadXPath,
      );
    }
    
    // 跳转到播放页面
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OptimizedVideoPlayerScreen(
            anime: _detailedAnime ?? widget.anime,
            episodeNumber: episodeNumber,
            sourceRule: effectiveRule,
          ),
        ),
      );
    }
  }

  Widget _buildEpisodeGrid() {
    final anime = _detailedAnime ?? widget.anime;
    
    // 如果有详细的集数列表，使用它
    if (anime.episodeList != null && anime.episodeList!.isNotEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: anime.episodeList!.map((episode) {
          return ActionChip(
            label: Text(
              episode.title.length > 8 
                  ? '第${episode.episodeNumber}集'
                  : episode.title,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _playEpisode(episode.episodeNumber),
          );
        }).toList(),
      );
    } else {
      // 使用默认的集数显示
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(anime.episodes, (index) {
          return ActionChip(
            label: Text(
              '第${index + 1}集',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _playEpisode(index + 1),
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在选择路线，显示简单的加载界面
    if (_isSelectingRoad) {
      return Scaffold(
        body: Column(
          children: [
            // 自定义应用栏
            Material(
              color: const Color(0xFF2d2d2d),
              elevation: 4,
              child: Container(
                height: 60,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.anime.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 加载提示
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      '正在加载路线信息...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Scaffold(
      body: Column(
        children: [
          // 自定义应用栏
          Material(
            color: const Color(0xFF2d2d2d),
            elevation: 4,
            child: Container(
              height: 60,
              child: Row(
                children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _detailedAnime?.title ?? widget.anime.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Consumer<FavoritesProvider>(
                  builder: (context, favoritesProvider, child) {
                    final isFavorite = favoritesProvider.isFavorite(widget.anime.id);
                    return IconButton(
                      onPressed: () {
                        favoritesProvider.toggleFavorite(widget.anime);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFavorite ? '已取消收藏' : '已添加到收藏',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            ),
          ),
          
          // 主要内容
          Expanded(
            child: _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: DetailPageSkeleton(),
                  )
                : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部信息区域 - 带模糊背景
                  Container(
                    height: 350,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // 模糊背景
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: _detailedAnime?.imageUrl ?? widget.anime.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[900],
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                        // 模糊效果 - 限制在容器内
                        Positioned.fill(
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        // 内容
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 动漫封面
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 200,
                                    height: 280,
                                    child: CachedNetworkImage(
                                      imageUrl: _detailedAnime?.imageUrl ?? widget.anime.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const SkeletonLoader(
                                        width: 200,
                                        height: 280,
                                        borderRadius: BorderRadius.all(Radius.circular(12)),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[800],
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: 48,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '图片加载失败',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(width: 24),
                                
                                // 动漫信息
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 标题
                                      Text(
                                        _detailedAnime?.title ?? widget.anime.title,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // 集数信息
                                      Text(
                                        '共 ${_detailedAnime?.episodes ?? widget.anime.episodes} 集',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 简介
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '简介',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _detailedAnime?.description ?? widget.anime.description,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 剧集列表
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '剧集',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildEpisodeGrid(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
