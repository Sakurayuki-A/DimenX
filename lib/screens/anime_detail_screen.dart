import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../services/anime_detail_service.dart';
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
  
  @override
  void initState() {
    super.initState();
    _detailedAnime = widget.anime;
    
    // 添加到观看历史
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().addToHistory(widget.anime);
    });
    
    // 如果有源规则，获取详细信息
    if (widget.sourceRule != null) {
      _fetchAnimeDetail();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _fetchAnimeDetail() async {
    try {
      final detailService = AnimeDetailService();
      final detailedAnime = await detailService.fetchAnimeDetail(widget.anime, widget.sourceRule!);
      
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

  Widget _buildEpisodeGrid() {
    final anime = _detailedAnime ?? widget.anime;
    
    // 如果有详细的集数列表，使用它
    if (anime.episodeList != null && anime.episodeList!.isNotEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          childAspectRatio: 1.8,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: anime.episodeList!.length,
        itemBuilder: (context, index) {
          final episode = anime.episodeList![index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OptimizedVideoPlayerScreen(
                    anime: anime,
                    episodeNumber: episode.episodeNumber,
                    sourceRule: widget.sourceRule,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey[600]!,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  episode.title.length > 8 
                      ? '第${episode.episodeNumber}集'
                      : episode.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        },
      );
    } else {
      // 使用默认的集数显示
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          childAspectRatio: 1.8,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: anime.episodes,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OptimizedVideoPlayerScreen(
                    anime: anime,
                    episodeNumber: index + 1,
                    sourceRule: widget.sourceRule,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey[600]!,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '第${index + 1}集',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          '正在获取详细信息...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
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
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
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
