import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../services/anime_detail_service.dart';
import '../widgets/skeleton_loader.dart';
import 'video_player_screen.dart';

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
          crossAxisCount: 8,
          childAspectRatio: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: anime.episodeList!.length,
        itemBuilder: (context, index) {
          final episode = anime.episodeList![index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    anime: anime,
                    episodeNumber: episode.episodeNumber,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[600]!,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  episode.title.length > 8 
                      ? '第${episode.episodeNumber}集'
                      : episode.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
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
          crossAxisCount: 8,
          childAspectRatio: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: anime.episodes,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    anime: anime,
                    episodeNumber: index + 1,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[600]!,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '第${index + 1}集',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
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
          Container(
            height: 60,
            color: const Color(0xFF2d2d2d),
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
                  // 头部信息区域
                  Container(
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
                                width: double.infinity,
                                height: double.infinity,
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
                                ),
                              ),
                            ],
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
