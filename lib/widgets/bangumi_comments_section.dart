import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/bangumi_comment_service.dart';

/// Bangumi评论区组件
class BangumiCommentsSection extends StatefulWidget {
  final String animeName;
  final String animeDescription;
  final List<String> tags;
  
  const BangumiCommentsSection({
    super.key,
    required this.animeName,
    this.animeDescription = '',
    this.tags = const [],
  });
  
  @override
  State<BangumiCommentsSection> createState() => _BangumiCommentsSectionState();
}

class _BangumiCommentsSectionState extends State<BangumiCommentsSection> {
  final BangumiCommentService _commentService = BangumiCommentService();
  List<BangumiStaff> _staff = [];
  List<BangumiCharacter> _characters = [];
  bool _isLoadingStaff = false;
  bool _isLoadingCharacters = false;
  String? _staffError;
  String? _charactersError;
  
  @override
  void initState() {
    super.initState();
    // 加载制作人员和角色
    _loadStaff();
    _loadCharacters();
  }
  
  Future<void> _loadCharacters() async {
    setState(() {
      _isLoadingCharacters = true;
      _charactersError = null;
    });
    
    try {
      final characters = await _commentService.getCharactersByName(widget.animeName);
      
      if (mounted) {
        setState(() {
          _characters = characters;
          _isLoadingCharacters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _charactersError = '加载角色失败';
          _isLoadingCharacters = false;
        });
      }
    }
  }
  
  Future<void> _loadStaff() async {
    setState(() {
      _isLoadingStaff = true;
      _staffError = null;
    });
    
    try {
      final staff = await _commentService.getStaffByName(widget.animeName);
      
      if (mounted) {
        setState(() {
          _staff = staff;
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _staffError = '加载制作人员失败';
          _isLoadingStaff = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标签栏
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: const Border(
                  bottom: BorderSide.none,
                ),
              ),
              child: TabBar(
                isScrollable: false,
                indicatorColor: const Color(0xFF008080),
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF008080),
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: '概览'),
                  Tab(text: '吐槽'),
                  Tab(text: '角色'),
                  Tab(text: '制作人员'),
                ],
              ),
            ),
            
            // 标签内容
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: TabBarView(
                  children: [
                    _buildOverviewTab(),
                    _buildCommentsTab(),
                    _buildCharactersTab(),
                    _buildStaffTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 概览标签
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 简介标题
          Row(
            children: [
              const Icon(
                Icons.description,
                color: Color(0xFF008080),
                size: 20,
              ),
              const SizedBox(width: 8),
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
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 简介内容
          Text(
            widget.animeDescription.isNotEmpty 
                ? widget.animeDescription 
                : '暂无简介信息',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 标签部分
          if (widget.tags.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.label,
                  color: Color(0xFF008080),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF008080)
                        : Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 标签网格
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.tags.map((tag) => _buildTagChip(tag)).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  /// 构建标签芯片
  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
  
  /// 吐槽标签
  Widget _buildCommentsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '吐槽内容',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  /// 角色标签
  Widget _buildCharactersTab() {
    if (_isLoadingCharacters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载角色...'),
            ],
          ),
        ),
      );
    }
    
    if (_charactersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _charactersError!,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCharacters,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_characters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '暂无角色信息',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _characters.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _buildCharacterItem(_characters[index]);
      },
    );
  }

  /// 构建角色项
  Widget _buildCharacterItem(BangumiCharacter character) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 头像
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: character.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: character.image,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 30),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 30),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 30),
                    ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (character.role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    character.role,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF008080),
                    ),
                  ),
                ],
                if (character.actor.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'CV: ${character.actor}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 制作人员标签
  Widget _buildStaffTab() {
    if (_isLoadingStaff) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载制作人员...'),
            ],
          ),
        ),
      );
    }
    
    if (_staffError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _staffError!,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStaff,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_staff.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                '暂无制作人员信息',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _staff.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _buildStaffItem(_staff[index]);
      },
    );
  }
  
  /// 构建制作人员项
  Widget _buildStaffItem(BangumiStaff staff) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 头像
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: staff.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: staff.image,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 30),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 30),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 30),
                    ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (staff.role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    staff.role,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
