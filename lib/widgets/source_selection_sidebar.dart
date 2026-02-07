import 'package:flutter/material.dart';
import '../models/source_rule.dart';
import '../models/anime.dart';
import '../services/anime_search_service.dart';
import 'anime_selection_dialog.dart';

/// 播放源选择下边栏
class SourceSelectionSidebar extends StatefulWidget {
  final Anime anime;
  final List<SourceRule> availableSources;
  final Function(SourceRule, {String? customQuery, Anime? selectedAnime}) onSourceSelected;
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
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;
  
  // 搜索状态
  final Map<String, bool> _searchLoading = {};
  final Map<String, List<Anime>> _searchResults = {};
  final Map<String, String?> _searchErrors = {};

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // 从底部向上滑动
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // 初始化 TabController
    _tabController = TabController(
      length: widget.availableSources.length,
      vsync: this,
    );
    
    _animationController.forward();
    
    // 自动开始搜索所有播放源
    _searchAllSources();
  }
  
  /// 搜索所有播放源
  Future<void> _searchAllSources() async {
    for (final source in widget.availableSources) {
      _searchSource(source);
    }
  }
  
  /// 搜索单个播放源
  Future<void> _searchSource(SourceRule source) async {
    setState(() {
      _searchLoading[source.id] = true;
      _searchErrors[source.id] = null;
    });
    
    try {
      final searchService = AnimeSearchService();
      final results = await searchService.searchAnimes(
        widget.anime.title,
        [source],
      );
      
      if (mounted) {
        setState(() {
          _searchLoading[source.id] = false;
          _searchResults[source.id] = results;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchLoading[source.id] = false;
          _searchErrors[source.id] = e.toString();
          _searchResults[source.id] = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;
    
    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
          margin: const EdgeInsets.only(top: 60),
          child: Material(
            elevation: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 32,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖动指示器
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // 头部
                  _buildHeader(context),
                  
                  // TabBar
                  if (widget.availableSources.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).dividerColor.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Stack(
                        children: [
                          TabBar(
                            controller: _tabController,
                            isScrollable: widget.availableSources.length > 3,
                            tabAlignment: widget.availableSources.length > 3 
                                ? TabAlignment.center 
                                : TabAlignment.fill,
                            indicatorColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor,
                            indicatorWeight: 3,
                            labelColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor,
                            unselectedLabelColor: Colors.grey[600],
                            labelStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            tabs: widget.availableSources.map((source) {
                              final isLoading = _searchLoading[source.id] ?? false;
                              final results = _searchResults[source.id] ?? [];
                              final hasError = _searchErrors[source.id] != null;
                              final isOnline = !isLoading && results.isNotEmpty;
                              final isOffline = !isLoading && results.isEmpty;
                              
                              return Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(source.name),
                                    const SizedBox(width: 8),
                                    if (isLoading)
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFF008080)
                                                : Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      )
                                    else if (isOnline)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    else if (isOffline || hasError)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          // 顶部加载进度条
                          if (widget.availableSources.any((s) => _searchLoading[s.id] ?? false))
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF008080)
                                      : Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  
                  // TabBarView
                  Expanded(
                    child: widget.availableSources.isEmpty
                        ? _buildEmptyState()
                        : TabBarView(
                            controller: _tabController,
                            children: widget.availableSources.map((source) {
                              return _buildSourceDetail(source);
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF008080).withOpacity(0.15)
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_circle_outline,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF008080)
                      : Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '选择播放源',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _close,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.anime.title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '可用播放源 (${widget.availableSources.length})',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.titleMedium?.color?.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildSourceDetail(SourceRule source) {
    final isLoading = _searchLoading[source.id] ?? false;
    final results = _searchResults[source.id] ?? [];
    final error = _searchErrors[source.id];
    
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF008080)
                    : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '正在搜索"${widget.anime.title}"...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              '搜索失败',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _searchSource(source),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的动漫',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在 ${source.name} 中没有找到"${widget.anime.title}"',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    // 显示搜索结果列表
    // 过滤掉无效结果
    final validResults = results.where((anime) {
      final title = anime.title.toLowerCase();
      // 过滤掉常见的无效标题
      final invalidTitles = [
        '本地记录',
        '查看更多',
        '更多',
        '首页',
        '排行',
        '分类',
        '搜索',
        '历史',
        '收藏',
        '设置',
        '关于',
        '帮助',
        '反馈',
        '登录',
        '注册',
      ];
      
      // 检查是否包含无效关键词
      for (final invalid in invalidTitles) {
        if (title == invalid.toLowerCase() || title.contains(invalid.toLowerCase())) {
          return false;
        }
      }
      
      // 检查 URL 是否有效
      if (anime.detailUrl.isEmpty || 
          anime.detailUrl.contains('/user/') ||
          anime.detailUrl.contains('/plays.html') ||
          anime.detailUrl.endsWith('/')) {
        return false;
      }
      
      return true;
    }).toList();
    
    if (validResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '未找到有效的动漫',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '在 ${source.name} 中没有找到有效结果',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: validResults.length,
        itemBuilder: (context, index) {
          final anime = validResults[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                anime.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: anime.detailUrl.isNotEmpty
                  ? Text(
                      anime.detailUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Icon(
                Icons.play_circle_outline,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF008080)
                    : Theme.of(context).primaryColor,
              ),
              onTap: () async {
                await _close();
                widget.onSourceSelected(source, selectedAnime: anime);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]?.withOpacity(0.3)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.grey[400],
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            '暂无可用播放源',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '请在设置中添加播放源规则',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _previewSearchResults(SourceRule source) async {
    final searchKeyword = widget.anime.title;
    
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
      final searchService = AnimeSearchService();
      final results = await searchService.searchAnimes(searchKeyword, [source]);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (results.isEmpty) {
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
        await _close();
        widget.onSourceSelected(
          source,
          selectedAnime: results.first,
        );
      } else {
        if (mounted) {
          showAnimeSelectionDialog(
            context,
            animes: results,
            searchKeyword: searchKeyword,
            onAnimeSelected: (selectedAnime) async {
              await _close();
              widget.onSourceSelected(
                source,
                selectedAnime: selectedAnime,
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      
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

/// 显示播放源选择下边栏的方法
void showSourceSelectionSidebar(
  BuildContext context, {
  required Anime anime,
  required List<SourceRule> availableSources,
  required Function(SourceRule, {String? customQuery, Anime? selectedAnime}) onSourceSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) {
      return SourceSelectionSidebar(
        anime: anime,
        availableSources: availableSources,
        onSourceSelected: onSourceSelected,
        onClose: () => Navigator.of(context).pop(),
      );
    },
  );
}
