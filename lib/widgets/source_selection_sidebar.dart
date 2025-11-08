import 'package:flutter/material.dart';
import '../models/source_rule.dart';
import '../models/anime.dart';
import '../services/anime_search_service.dart';
import 'anime_selection_dialog.dart';

/// 播放源选择侧边栏
class SourceSelectionSidebar extends StatefulWidget {
  final Anime anime;
  final List<SourceRule> availableSources;
  final Function(SourceRule, {String? customQuery}) onSourceSelected;
  final VoidCallback onClose;

  const SourceSelectionSidebar({
    super.key,
    required this.anime,
    required this.availableSources,
    required this.onSourceSelected,
    required this.onClose,
  });

  @override
  State<SourceSelectionSidebar> createState() => _SourceSelectionSidebarState();
}

class _SourceSelectionSidebarState extends State<SourceSelectionSidebar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.anime.title;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 16,
        child: Container(
          width: 400,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
        child: Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]
                    : Colors.grey[50],
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF008080)
                            : Theme.of(context).primaryColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '选择播放源',
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
                  
                  // 动漫标题
                  Text(
                    widget.anime.title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 自定义搜索框
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.edit,
                                size: 20,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF008080)
                                    : Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '自定义搜索关键词',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {}); // 触发重建以更新智能建议
                            },
                            decoration: InputDecoration(
                              hintText: '例如：命运石之门零、命运石之门0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[700]
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          
                          // 智能搜索建议
                          if (_searchController.text.contains(' '))
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    size: 16,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '建议尝试：',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _searchController.text = _searchController.text.replaceAll(' ', '');
                                            });
                                          },
                                          child: Text(
                                            '"${_searchController.text.replaceAll(' ', '')}"',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange[700],
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _searchController.text = _searchController.text.replaceAll(' ', '');
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[700],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '应用',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          Text(
                            '搜索提示：\n• 如果搜索不到结果，尝试去掉空格（如：碧蓝之海第二季）\n• 可以使用简化名称（如：碧蓝之海2）\n• 不同播放源对关键词敏感度不同',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 播放源标题
                    Text(
                      '可用播放源 (${widget.availableSources.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 播放源列表
                    if (widget.availableSources.isEmpty)
                      _buildEmptyState()
                    else
                      ...widget.availableSources.map((source) => _buildSourceItem(context, source)),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.grey[400],
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无可用播放源',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请在设置中添加播放源规则',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceItem(BuildContext context, SourceRule source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            // 主要信息区域
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                onTap: () {
                  final customQuery = _searchController.text.trim();
                  widget.onSourceSelected(
                    source,
                    customQuery: customQuery.isNotEmpty && customQuery != widget.anime.title 
                        ? customQuery 
                        : null,
                  );
                  _close();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // 播放源图标
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF008080).withOpacity(0.1)
                              : Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF008080)
                              : Theme.of(context).primaryColor,
                          size: 24,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 播放源信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              source.baseURL,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // 直接播放图标
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 搜索预览按钮
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.3),
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  onTap: () => _previewSearchResults(source),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF008080)
                              : Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '搜索预览 - 查看所有匹配作品',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF008080)
                                  : Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.visibility,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF008080)
                              : Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 预览搜索结果
  Future<void> _previewSearchResults(SourceRule source) async {
    final customQuery = _searchController.text.trim();
    final searchKeyword = customQuery.isNotEmpty ? customQuery : widget.anime.title;
    
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在搜索"$searchKeyword"...'),
          ],
        ),
      ),
    );
    
    try {
      // 执行搜索
      final searchService = AnimeSearchService();
      final results = await searchService.searchAnimes(searchKeyword, [source]);
      
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (results.isEmpty) {
        // 没有找到结果
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('搜索结果'),
              content: Text('在 ${source.name} 中没有找到"$searchKeyword"的相关作品'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
      } else if (results.length == 1) {
        // 只有一个结果，直接选择
        widget.onSourceSelected(
          source,
          customQuery: searchKeyword != widget.anime.title ? searchKeyword : null,
        );
        _close();
      } else {
        // 多个结果，显示选择对话框
        if (mounted) {
          showAnimeSelectionDialog(
            context,
            animes: results,
            searchKeyword: searchKeyword,
            onAnimeSelected: (selectedAnime) {
              // 用户选择了具体作品，使用该作品的标题作为搜索关键词
              widget.onSourceSelected(
                source,
                customQuery: selectedAnime.title,
              );
              _close();
            },
          );
        }
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // 显示错误信息
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('搜索失败'),
            content: Text('搜索过程中出现错误：$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }
}

/// 显示播放源选择侧边栏的方法
void showSourceSelectionSidebar(
  BuildContext context, {
  required Anime anime,
  required List<SourceRule> availableSources,
  required Function(SourceRule, {String? customQuery}) onSourceSelected,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.3),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SourceSelectionSidebar(
          anime: anime,
          availableSources: availableSources,
          onSourceSelected: onSourceSelected,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    },
  );
}
