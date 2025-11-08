import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/anime.dart';

/// 动漫作品选择对话框
class AnimeSelectionDialog extends StatefulWidget {
  final List<Anime> animes;
  final String searchKeyword;
  final Function(Anime) onAnimeSelected;

  const AnimeSelectionDialog({
    super.key,
    required this.animes,
    required this.searchKeyword,
    required this.onAnimeSelected,
  });

  @override
  State<AnimeSelectionDialog> createState() => _AnimeSelectionDialogState();
}

class _AnimeSelectionDialogState extends State<AnimeSelectionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 700,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    Flexible(
                      child: _buildAnimeList(),
                    ),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.search,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF008080)
                    : Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '选择作品',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
              IconButton(
                onPressed: _close,
                icon: const Icon(Icons.close),
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              children: [
                const TextSpan(text: '搜索关键词："'),
                TextSpan(
                  text: widget.searchKeyword,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF008080)
                        : Theme.of(context).primaryColor,
                  ),
                ),
                TextSpan(text: '"找到 ${widget.animes.length} 个相关作品'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeList() {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: widget.animes.length,
      itemBuilder: (context, index) {
        final anime = widget.animes[index];
        return _buildAnimeItem(anime, index);
      },
    );
  }

  Widget _buildAnimeItem(Anime anime, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onAnimeSelected(anime);
            _close();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                // 动漫封面
                Container(
                  width: 80,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[300],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: anime.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: anime.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[600],
                                size: 32,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.movie,
                              color: Colors.grey[600],
                              size: 32,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 动漫信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Text(
                        anime.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 来源信息
                      if (anime.genres.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080).withOpacity(0.1)
                                : Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '来源: ${anime.genres.first}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF008080)
                                  : Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // 描述信息
                      if (anime.description.isNotEmpty)
                        Text(
                          anime.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 8),
                      
                      // 相关性指示器
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: _getRelevanceColor(anime.title, widget.searchKeyword),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getRelevanceText(anime.title, widget.searchKeyword),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getRelevanceColor(anime.title, widget.searchKeyword),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 选择指示器
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF008080).withOpacity(0.1)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF008080)
                        : Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '点击任意作品开始播放，系统会自动解析视频源',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取相关性颜色
  Color _getRelevanceColor(String title, String keyword) {
    final score = _calculateRelevanceScore(title, keyword);
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.grey;
  }

  /// 获取相关性文本
  String _getRelevanceText(String title, String keyword) {
    final score = _calculateRelevanceScore(title, keyword);
    if (score >= 80) return '高度匹配';
    if (score >= 60) return '部分匹配';
    return '相关';
  }

  /// 计算相关性评分（与搜索服务保持一致）
  double _calculateRelevanceScore(String title, String keyword) {
    final lowerTitle = title.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    double score = 0.0;
    
    // 完全匹配得分最高
    if (lowerTitle == lowerKeyword) {
      score += 100.0;
    }
    // 标题开头匹配
    else if (lowerTitle.startsWith(lowerKeyword)) {
      score += 80.0;
    }
    // 标题包含完整关键词
    else if (lowerTitle.contains(lowerKeyword)) {
      score += 60.0;
    }
    
    // 检查关键词的各个部分
    final keywordParts = lowerKeyword.split(RegExp(r'[\s\-_]+'));
    int matchedParts = 0;
    
    for (final part in keywordParts) {
      if (part.isNotEmpty && lowerTitle.contains(part)) {
        matchedParts++;
        score += 15.0;
      }
    }
    
    // 如果关键词有多个部分，检查匹配比例
    if (keywordParts.length > 1) {
      final matchRatio = matchedParts / keywordParts.length;
      if (matchRatio < 0.6) {
        score *= 0.5; // 降低评分
      }
    }
    
    // 强化续集惩罚机制
    if (!lowerKeyword.contains('第') && !lowerKeyword.contains('季') && 
        !lowerKeyword.contains('season') && !lowerKeyword.contains('s2') && 
        !lowerKeyword.contains('s3') && !lowerKeyword.contains('2') && 
        !lowerKeyword.contains('二')) {
      
      // 检查是否为续集
      bool isSequel = false;
      final sequelPatterns = [
        '第二季', '第三季', '第四季', '第五季',
        'season 2', 'season 3', 'season 4', 'season 5',
        's2', 's3', 's4', 's5',
        '2nd season', '3rd season', '4th season',
        'ii', 'iii', 'iv', 'v',
        '2期', '3期', '4期', '5期',
        '续', '新', '再'
      ];
      
      for (final pattern in sequelPatterns) {
        if (lowerTitle.contains(pattern)) {
          isSequel = true;
          break;
        }
      }
      
      if (isSequel) {
        // 如果关键词完全匹配基础名称，续集应该得到更严厉的惩罚
        final baseTitle = lowerTitle.replaceAll(RegExp(r'第[二三四五]季|season [2-5]|s[2-5]|2nd season|3rd season|4th season|ii|iii|iv|v|[2-5]期'), '').trim();
        if (baseTitle == lowerKeyword || baseTitle.startsWith(lowerKeyword)) {
          score *= 0.1; // 极大降低续集评分
        } else {
          score *= 0.3; // 一般续集惩罚
        }
      }
    }
    
    // 额外的精确匹配奖励
    if (lowerTitle == lowerKeyword) {
      score += 50.0; // 额外奖励精确匹配
    }
    
    // 长度相似性奖励（避免过长标题获得高分）
    final lengthDiff = (lowerTitle.length - lowerKeyword.length).abs();
    if (lengthDiff <= 2) {
      score += 20.0; // 长度相似奖励
    } else if (lengthDiff > 10) {
      score *= 0.8; // 长度差异惩罚
    }
    
    return score;
  }
}

/// 显示动漫选择对话框
Future<void> showAnimeSelectionDialog(
  BuildContext context, {
  required List<Anime> animes,
  required String searchKeyword,
  required Function(Anime) onAnimeSelected,
}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => AnimeSelectionDialog(
      animes: animes,
      searchKeyword: searchKeyword,
      onAnimeSelected: onAnimeSelected,
    ),
  );
}
