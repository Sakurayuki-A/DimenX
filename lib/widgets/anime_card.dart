import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';
import 'skeleton_loader.dart';

class AnimeCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback onTap;

  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
  });

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 验证图片URL是否有效
  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    // 检查是否是有效的URL格式
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) return false;
      
      // 检查是否有有效的域名
      if (uri.host.isEmpty || uri.host == 'img.test.com') return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 构建占位图片
  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[700]!,
            Colors.grey[900]!,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie,
            color: Colors.grey[400],
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            widget.anime.title.length > 10 
                ? '${widget.anime.title.substring(0, 10)}...'
                : widget.anime.title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _animationController.forward();
      },
      onExit: (_) {
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 动漫封面
                  Hero(
                    tag: 'anime_image_${widget.anime.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                          child: _isValidImageUrl(widget.anime.imageUrl)
                              ? CachedNetworkImage(
                                  imageUrl: widget.anime.imageUrl,
                                  fit: BoxFit.cover,
                                  // 启用内存和磁盘缓存
                                  memCacheWidth: 400,
                                  memCacheHeight: 600,
                                  maxWidthDiskCache: 800,
                                  maxHeightDiskCache: 1200,
                                  // 加载中显示骨架屏
                                  placeholder: (context, url) => const SkeletonLoader(
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                  // 错误时显示占位图
                                  errorWidget: (context, url, error) => _buildPlaceholderImage(),
                                  // 禁用淡入动画，避免Hero动画白闪
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
                  
                  const SizedBox(height: 8),
                  
                  // 动漫名称
                  Text(
                    widget.anime.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // 评分和年份
                  Row(
                    children: [
                      if (widget.anime.rating > 0) ...[
                        Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.anime.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF008080),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.anime.year.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
