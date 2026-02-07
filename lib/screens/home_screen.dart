import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../providers/anime_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/source_rule_provider.dart';
import '../models/source_rule.dart';
import '../services/cache_manager.dart';
import '../widgets/sidebar.dart';
import '../widgets/anime_grid.dart';
import '../widgets/anime_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/skeleton_loader.dart';
import 'anime_detail_screen_simple.dart';
import 'bangumi_anime_detail_screen.dart';
import 'anime_calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnimeProvider>().loadAnimes();
      context.read<FavoritesProvider>().loadFavorites();
      context.read<HistoryProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 6;
    if (width > 1200) return 5;
    if (width > 1000) return 4;
    if (width > 800) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 主要内容区域
          Expanded(
            child: Row(
              children: [
                // 侧边栏
                SizedBox(
                  width: 80,
                  child: Sidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                      // 只有在离开搜索页面时才清除搜索
                      if (_selectedIndex != 4 && index != 4) {
                        _searchController.clear();
                        context.read<AnimeProvider>().clearSearch();
                      }
                    },
                  ),
                ),
                
                // 主内容区域
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        // 内容区域 - 滑动动画
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.3),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              key: ValueKey(_selectedIndex),
                              child: _buildContent(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: // 首页
        return _buildHomeContent();
      case 1: // 收藏
        return _buildFavoritesContent();
      case 2: // 历史
        return _buildHistoryContent();
      case 3: // 设置
        return _buildSettingsContent();
      case 4: // 搜索
        return _buildSearchContent();
      case 5: // 时间表
        return const AnimeCalendarScreen();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return Consumer<AnimeProvider>(
      builder: (context, animeProvider, child) {
        if (animeProvider.isLoading) {
          // 显示骨架屏加载动画
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题骨架
                Row(
                  children: [
                    SkeletonLoader(
                      width: 24,
                      height: 24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(width: 8),
                    const SkeletonLoader(
                      width: 120,
                      height: 20,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 动漫卡片骨架网格
                MasonryGridView.count(
                  crossAxisCount: _getCrossAxisCount(context),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: 12, // 显示12个骨架屏
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return const AnimeCardSkeleton();
                  },
                ),
              ],
            ),
          );
        }

        if (animeProvider.error.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  animeProvider.error,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => animeProvider.loadAnimes(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final animes = animeProvider.animes;
        final bangumiRecommendations = animeProvider.bangumiRecommendations;

        if (animes.isEmpty && bangumiRecommendations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无动漫数据',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(), // 确保滚动始终可用
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bangumi推荐区域
              if (bangumiRecommendations.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.whatshot,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF008080)
                          : Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '当季热门动漫',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: 跳转到更多推荐页面
                      },
                      child: const Text('查看更多'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MasonryGridView.count(
                  crossAxisCount: _getCrossAxisCount(context),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: bangumiRecommendations.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return AnimeCard(
                      anime: bangumiRecommendations[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BangumiAnimeDetailScreen(
                              anime: bangumiRecommendations[index],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
              
              // 本地动漫区域
              if (animes.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.local_movies,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF008080)
                          : Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '本地收藏',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MasonryGridView.count(
                  crossAxisCount: _getCrossAxisCount(context),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: animes.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return AnimeCard(
                      anime: animes[index],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnimeDetailScreenSimple(
                              anime: animes[index],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesContent() {
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final favorites = favoritesProvider.favorites;
        if (favorites.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '暂无收藏的动漫',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return AnimeGrid(
          animes: favoritesProvider.favorites,
          onAnimeSelected: (anime) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BangumiAnimeDetailScreen(
                  anime: anime,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryContent() {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        if (historyProvider.history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '暂无观看历史',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 清除历史按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '观看历史',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await context.read<HistoryProvider>().cleanupDuplicates();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('重复记录清理完成'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('清理重复'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('清除历史记录'),
                          content: const Text('确定要清除所有观看历史吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                historyProvider.clearHistory();
                                Navigator.pop(context);
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清除历史'),
                  ),
                ],
              ),
            ),
            
            // 历史记录列表
            Expanded(
              child: AnimeGrid(
                animes: historyProvider.history.map((item) => item.anime).toList(),
                onAnimeSelected: (anime) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnimeDetailScreenSimple(
                        anime: anime,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchContent() {
    return Consumer<AnimeProvider>(
      builder: (context, animeProvider, child) {
        return Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomSearchBar(
                controller: _searchController,
                onSearch: (query) {
                  context.read<AnimeProvider>().searchAnimes(query);
                },
              ),
            ),
            
            // 搜索结果
            Expanded(
              child: _buildSearchResults(animeProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(AnimeProvider animeProvider) {
    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '输入关键词搜索动漫',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    if (animeProvider.isLoading) {
      // 搜索加载时显示骨架屏
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: MasonryGridView.count(
          crossAxisCount: _getCrossAxisCount(context),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          itemCount: 8, // 显示8个骨架屏
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return const AnimeCardSkeleton();
          },
        ),
      );
    }

    final searchResults = animeProvider.searchResults;

    if (searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '未找到相关动漫',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: MasonryGridView.count(
        crossAxisCount: _getCrossAxisCount(context),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemCount: searchResults.length,
        physics: const AlwaysScrollableScrollPhysics(), // 启用滚动
        itemBuilder: (context, index) {
          return AnimeCard(
            anime: searchResults[index],
            onTap: () {
              // 所有搜索结果都是Bangumi来源，显示详情页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BangumiAnimeDetailScreen(
                    anime: searchResults[index],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 设置标题
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              
              // 主题设置卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.palette,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '主题设置',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 主题选项
                      _buildThemeOption(
                        context,
                        themeProvider,
                        '浅色模式',
                        Icons.light_mode,
                        AppThemeMode.light,
                      ),
                      const SizedBox(height: 12),
                      _buildThemeOption(
                        context,
                        themeProvider,
                        '深色模式',
                        Icons.dark_mode,
                        AppThemeMode.dark,
                      ),
                      const SizedBox(height: 12),
                      _buildThemeOption(
                        context,
                        themeProvider,
                        '跟随系统',
                        Icons.brightness_auto,
                        AppThemeMode.system,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 规则配置卡片
              Consumer<SourceRuleProvider>(
                builder: (context, ruleProvider, child) {
                  return Card(
                    child: ExpansionTile(
                      leading: Icon(
                        Icons.settings_applications,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF008080) // 深色模式下使用青色
                            : Theme.of(context).primaryColor,
                        size: 24,
                      ),
                      title: const Text(
                        '规则配置',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '已配置 ${ruleProvider.rules.length} 个规则 (XPath格式)',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              // 添加规则按钮
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddRuleDialog(context, ruleProvider),
                                  icon: const Icon(Icons.add),
                                  label: const Text('添加新规则'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // 规则列表
                              if (ruleProvider.rules.isEmpty)
                                const Center(
                                  child: Text(
                                    '暂无配置规则',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              else
                                ...ruleProvider.rules.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final rule = entry.value;
                                  return _buildRuleItem(context, ruleProvider, rule, index);
                                }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // 缓存管理卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storage,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '缓存管理',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // 缓存统计信息
                      Builder(
                        builder: (context) {
                          final cacheStats = CacheManager().getCacheStats();
                          return Column(
                            children: [
                              _buildInfoRow('已缓存星期数', '${cacheStats['cachedWeekdays']} 个'),
                              _buildInfoRow('已缓存番剧数', '${cacheStats['totalAnime']} 个'),
                              _buildInfoRow('热门推荐缓存', '${cacheStats['bangumiListCache']} 项'),
                              _buildInfoRow('详情页缓存', '${cacheStats['bangumiDetailCache']} 项'),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 清除缓存按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showClearCacheDialog(context),
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('清除API缓存'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      const Text(
                        '清除缓存后，时间表数据将重新从服务器加载',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 应用信息卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080) // 深色模式下使用青色
                                : Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '应用信息',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('应用名称', 'DimenX'),
                      _buildInfoRow('版本号', 'v1.0.0'),
                      _buildInfoRow('开发框架', 'Flutter'),
                      _buildInfoRow('开发者', 'AnimeHubX Team'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 开源许可证卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.code,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '开源许可证',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '本应用使用了以下开源项目',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showLicensePage(context),
                          icon: const Icon(Icons.article),
                          label: const Text('查看开源许可证'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF008080)
                                : Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建主题选项
  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    String title,
    IconData icon,
    AppThemeMode mode,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    
    return InkWell(
      onTap: () => themeProvider.setThemeMode(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF008080).withOpacity(0.2)
                  : const Color(0xFF008080).withOpacity(0.1))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF008080)
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[700]!
                    : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF008080)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600]),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF008080)
                      : null,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF008080),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 显示添加规则对话框
  void _showAddRuleDialog(BuildContext context, SourceRuleProvider ruleProvider) {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'name': TextEditingController(),
      'version': TextEditingController(),
      'baseURL': TextEditingController(),
      'searchURL': TextEditingController(),
      'searchList': TextEditingController(),
      'searchName': TextEditingController(),
      'searchResult': TextEditingController(),
      'imgRoads': TextEditingController(),
      'chapterRoads': TextEditingController(),
      'chapterResult': TextEditingController(),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新规则'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRuleField('规则名称', 'name', controllers['name']!),
                  _buildRuleField('版本', 'version', controllers['version']!),
                  _buildRuleField('基础URL', 'baseURL', controllers['baseURL']!),
                  _buildRuleField('搜索URL', 'searchURL', controllers['searchURL']!),
                  _buildRuleField('搜索列表', 'searchList', controllers['searchList']!),
                  _buildRuleField('搜索名称', 'searchName', controllers['searchName']!),
                  _buildRuleField('搜索结果', 'searchResult', controllers['searchResult']!),
                  _buildRuleField('图片路径', 'imgRoads', controllers['imgRoads']!),
                  _buildRuleField('章节路径', 'chapterRoads', controllers['chapterRoads']!),
                  _buildRuleField('章节结果', 'chapterResult', controllers['chapterResult']!),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final rule = SourceRule(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controllers['name']!.text,
                  version: controllers['version']!.text,
                  baseURL: controllers['baseURL']!.text,
                  searchURL: controllers['searchURL']!.text,
                  searchList: controllers['searchList']!.text,
                  searchName: controllers['searchName']!.text,
                  searchResult: controllers['searchResult']!.text,
                  imgRoads: controllers['imgRoads']!.text,
                  chapterRoads: controllers['chapterRoads']!.text,
                  chapterResult: controllers['chapterResult']!.text,
                );
                ruleProvider.addRule(rule);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 构建规则输入字段
  Widget _buildRuleField(
    String label, 
    String key, 
    TextEditingController controller, {
    int? maxLines,
    String? helperText,
  }) {
    // XPath格式的提示信息
    final Map<String, String> xpathHints = {
      'name': '规则的名称，用于识别不同的源站，如: 7sefun',
      'version': '规则版本号，如: 1.0.0 或 待定',
      'baseURL': '源站的基础URL，如: https://7sefun.top/',
      'searchURL': '搜索页面的URL路径，如: https://www.7sefun.top/vodsearch/-------------.html?wd=@keyword',
      'searchList': 'XPath: 搜索结果列表的选择器，如: //div[2]/div[2]/div[2]/div[2]/div',
      'searchName': 'XPath: 动漫名称的选择器，如: //div[2]/text()',
      'searchResult': 'XPath: 动漫详情页链接的选择器，如: //a',
      'imgRoads': 'XPath: 动漫封面图片的选择器，如: //img/@src',
      'chapterRoads': 'XPath: 章节列表的选择器，如: //div[2]/div[2]/div[2]/div/div[2]/div[1]/div[2]',
      'chapterResult': 'XPath: 章节播放链接的选择器，如: //a',
      'roadList': 'XPath: 定位所有路线元素',
      'roadName': 'XPath: 从路线元素中提取名称',
    };
    
    // 确定最大行数
    final int effectiveMaxLines = maxLines ?? 
        (key.contains('URL') || key.contains('List') || key.contains('Result') || key.contains('Roads') ? 2 : 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: effectiveMaxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: xpathHints[key],
          helperText: helperText,
          border: const OutlineInputBorder(),
          helperMaxLines: 3,
        ),
        validator: (value) {
          // roadList 和 roadName 是可选的，不需要验证
          if (key == 'roadList' || key == 'roadName') {
            return null;
          }
          if (value == null || value.isEmpty) {
            return '请输入$label';
          }
          return null;
        },
      ),
    );
  }

  // 构建规则项
  Widget _buildRuleItem(BuildContext context, SourceRuleProvider ruleProvider, SourceRule rule, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(rule.name),
        subtitle: Text('版本: ${rule.version} | ${rule.baseURL}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '高级设置',
              onPressed: () => _showAdvancedSettingsDialog(context, ruleProvider, rule, index),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '编辑',
              onPressed: () => _showEditRuleDialog(context, ruleProvider, rule, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除',
              onPressed: () => _showDeleteRuleDialog(context, ruleProvider, index),
            ),
          ],
        ),
      ),
    );
  }

  // 显示编辑规则对话框
  void _showEditRuleDialog(BuildContext context, SourceRuleProvider ruleProvider, SourceRule rule, int index) {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'name': TextEditingController(text: rule.name),
      'version': TextEditingController(text: rule.version),
      'baseURL': TextEditingController(text: rule.baseURL),
      'searchURL': TextEditingController(text: rule.searchURL),
      'searchList': TextEditingController(text: rule.searchList),
      'searchName': TextEditingController(text: rule.searchName),
      'searchResult': TextEditingController(text: rule.searchResult),
      'imgRoads': TextEditingController(text: rule.imgRoads),
      'chapterRoads': TextEditingController(text: rule.chapterRoads),
      'chapterResult': TextEditingController(text: rule.chapterResult),
      'roadList': TextEditingController(text: rule.roadList),
      'roadName': TextEditingController(text: rule.roadName),
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑规则'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRuleField('规则名称', 'name', controllers['name']!),
                  _buildRuleField('版本', 'version', controllers['version']!),
                  _buildRuleField('基础URL', 'baseURL', controllers['baseURL']!),
                  _buildRuleField('搜索URL', 'searchURL', controllers['searchURL']!),
                  _buildRuleField('搜索列表', 'searchList', controllers['searchList']!),
                  _buildRuleField('搜索名称', 'searchName', controllers['searchName']!),
                  _buildRuleField('搜索结果', 'searchResult', controllers['searchResult']!),
                  _buildRuleField('图片路径', 'imgRoads', controllers['imgRoads']!),
                  _buildRuleField('章节路径', 'chapterRoads', controllers['chapterRoads']!),
                  _buildRuleField('章节结果', 'chapterResult', controllers['chapterResult']!),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '多路线配置（可选）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRuleField(
                    '路线列表',
                    'roadList',
                    controllers['roadList']!,
                    maxLines: 2,
                    helperText: 'XPath: 定位所有路线元素\n例如: //div[@class="van-tabs__nav"]/div',
                  ),
                  _buildRuleField(
                    '路线名称',
                    'roadName',
                    controllers['roadName']!,
                    maxLines: 2,
                    helperText: 'XPath: 从路线元素中提取名称\n例如: //span[@class="van-tab__text"]/text()',
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final updatedRule = SourceRule(
                  id: rule.id,
                  name: controllers['name']!.text,
                  version: controllers['version']!.text,
                  baseURL: controllers['baseURL']!.text,
                  searchURL: controllers['searchURL']!.text,
                  searchList: controllers['searchList']!.text,
                  searchName: controllers['searchName']!.text,
                  searchResult: controllers['searchResult']!.text,
                  imgRoads: controllers['imgRoads']!.text,
                  chapterRoads: controllers['chapterRoads']!.text,
                  chapterResult: controllers['chapterResult']!.text,
                  roadList: controllers['roadList']!.text,
                  roadName: controllers['roadName']!.text,
                );
                ruleProvider.updateRule(index, updatedRule);
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 显示高级设置对话框
  void _showAdvancedSettingsDialog(BuildContext context, SourceRuleProvider ruleProvider, SourceRule rule, int index) {
    bool enableDynamicLoading = rule.enableDynamicLoading;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${rule.name} - 高级设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '性能优化',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('启用动态加载'),
                  subtitle: const Text(
                    '使用 WebView 渲染 JavaScript（适用于 SPA 网站）\n'
                    '注意：会增加加载时间，仅在静态加载失败时启用',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: enableDynamicLoading,
                  onChanged: (value) {
                    setState(() {
                      enableDynamicLoading = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          enableDynamicLoading
                              ? '已启用：适用于 Vue/React 等 SPA 框架'
                              : '已禁用：使用快速静态加载',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedRule = rule.copyWith(
                  enableDynamicLoading: enableDynamicLoading,
                );
                ruleProvider.updateRule(index, updatedRule);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      enableDynamicLoading
                          ? '已启用动态加载，搜索速度可能变慢'
                          : '已禁用动态加载，使用快速静态加载',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // 显示删除规则确认对话框
  void _showDeleteRuleDialog(BuildContext context, SourceRuleProvider ruleProvider, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除规则'),
        content: const Text('确定要删除这个规则吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              ruleProvider.removeRule(index);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 显示清除缓存确认对话框
  void _showClearCacheDialog(BuildContext context) {
    final cacheStats = CacheManager().getCacheStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('清除缓存'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('确定要清除所有API缓存吗？'),
            const SizedBox(height: 16),
            Text(
              '将清除：',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text('• ${cacheStats['cachedWeekdays']} 个星期的时间表数据'),
            Text('• ${cacheStats['totalAnime']} 个番剧信息'),
            Text('• ${cacheStats['bangumiListCache']} 项热门推荐缓存'),
            Text('• ${cacheStats['bangumiDetailCache']} 项详情页缓存'),
            const SizedBox(height: 16),
            const Text(
              '清除后，数据将在下次访问时重新加载。',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              CacheManager().clearAllCache();
              Navigator.pop(context);
              
              // 显示成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('缓存已清除'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              
              // 刷新设置页面以更新缓存统计
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  // 显示开源许可证页面
  void _showLicensePage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开源许可证'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DimenX 使用了以下开源项目：',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildLicenseItem(
                  'Flutter',
                  'BSD-3-Clause License',
                  'Google Inc.',
                  'UI框架',
                ),
                
                _buildLicenseItem(
                  'media_kit',
                  'MIT License',
                  'Hitesh Kumar Saini',
                  '视频播放库',
                ),
                
                _buildLicenseItem(
                  'flutter_inappwebview',
                  'Apache License 2.0',
                  'Lorenzo Pichilli',
                  'WebView组件',
                ),
                
                _buildLicenseItem(
                  'http',
                  'BSD-3-Clause License',
                  'Dart Team',
                  'HTTP请求库',
                ),
                
                _buildLicenseItem(
                  'html',
                  'MIT License',
                  'Dart Team',
                  'HTML解析库',
                ),
                
                _buildLicenseItem(
                  'cached_network_image',
                  'MIT License',
                  'Baseflow',
                  '网络图片缓存',
                ),
                
                _buildLicenseItem(
                  'provider',
                  'MIT License',
                  'Remi Rousselet',
                  '状态管理',
                ),
                
                _buildLicenseItem(
                  'shared_preferences',
                  'BSD-3-Clause License',
                  'Flutter Team',
                  '本地存储',
                ),
                
                _buildLicenseItem(
                  'window_manager',
                  'MIT License',
                  'LeanFlutter',
                  '窗口管理',
                ),
                
                _buildLicenseItem(
                  'Bangumi API',
                  'Open API',
                  'Bangumi 番组计划',
                  '动漫数据源',
                ),
                
                _buildLicenseItem(
                  'flutter_staggered_grid_view',
                  'MIT License',
                  'Romain Rastel',
                  '瀑布流网格布局',
                ),
                
                _buildLicenseItem(
                  'path_provider',
                  'BSD-3-Clause License',
                  'Flutter Team',
                  '文件路径管理',
                ),
                
                _buildLicenseItem(
                  'sqflite',
                  'MIT License',
                  'Tekartik',
                  'SQLite数据库',
                ),
                
                _buildLicenseItem(
                  'flutter_localizations',
                  'BSD-3-Clause License',
                  'Flutter Team',
                  '国际化支持',
                ),
                
                _buildLicenseItem(
                  'intl',
                  'BSD-3-Clause License',
                  'Dart Team',
                  '国际化工具',
                ),
                
                _buildLicenseItem(
                  'url_launcher',
                  'BSD-3-Clause License',
                  'Flutter Team',
                  'URL启动器',
                ),
                
                _buildLicenseItem(
                  'package_info_plus',
                  'BSD-3-Clause License',
                  'Plus plugins team',
                  '应用信息获取',
                ),
                
                _buildLicenseItem(
                  'connectivity_plus',
                  'BSD-3-Clause License',
                  'Plus plugins team',
                  '网络连接检测',
                ),
                
                _buildLicenseItem(
                  'device_info_plus',
                  'BSD-3-Clause License',
                  'Plus plugins team',
                  '设备信息获取',
                ),
                
                _buildLicenseItem(
                  'permission_handler',
                  'MIT License',
                  'Baseflow',
                  '权限管理',
                ),
                
                _buildLicenseItem(
                  'file_picker',
                  'MIT License',
                  'Miguel Ruivo',
                  '文件选择器',
                ),
                
                _buildLicenseItem(
                  'flutter_svg',
                  'MIT License',
                  'Dan Field',
                  'SVG图像支持',
                ),
                
                _buildLicenseItem(
                  'lottie',
                  'Apache License 2.0',
                  'Airbnb',
                  '动画支持',
                ),
                
                _buildLicenseItem(
                  'dio',
                  'MIT License',
                  'Flutterchina',
                  '高级HTTP客户端',
                ),
                
                _buildLicenseItem(
                  'crypto',
                  'BSD-3-Clause License',
                  'Dart Team',
                  '加密算法库',
                ),
                
                _buildLicenseItem(
                  'xml',
                  'MIT License',
                  'Lukas Renggli',
                  'XML解析库',
                ),
                
                _buildLicenseItem(
                  'json_annotation',
                  'BSD-3-Clause License',
                  'Dart Team',
                  'JSON序列化注解',
                ),
                
                _buildLicenseItem(
                  'build_runner',
                  'BSD-3-Clause License',
                  'Dart Team',
                  '代码生成工具',
                ),
                
                _buildLicenseItem(
                  'flutter_launcher_icons',
                  'MIT License',
                  'Mark O\'Sullivan',
                  '应用图标生成',
                ),
                
                _buildLicenseItem(
                  'msix',
                  'BSD-3-Clause License',
                  'YehudaKremer',
                  'Windows应用打包',
                ),
                
                const SizedBox(height: 16),
                const Text(
                  '感谢所有开源项目的贡献者！',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 构建许可证项目
  Widget _buildLicenseItem(String name, String license, String author, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    license,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              'by $author',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
