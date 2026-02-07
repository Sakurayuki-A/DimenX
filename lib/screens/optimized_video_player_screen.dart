import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../services/video_extractor.dart';
import '../services/anime_detail_service.dart';

class OptimizedVideoPlayerScreen extends StatefulWidget {
  final Anime anime;
  final int episodeNumber;
  final SourceRule? sourceRule;

  const OptimizedVideoPlayerScreen({
    super.key,
    required this.anime,
    this.episodeNumber = 1,
    this.sourceRule,
  });

  @override
  State<OptimizedVideoPlayerScreen> createState() => _OptimizedVideoPlayerScreenState();
}

class _OptimizedVideoPlayerScreenState extends State<OptimizedVideoPlayerScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isLoading = true;
  bool _isExtracting = true;
  String? _error;
  String? _selectedVideoUrl;
  VideoExtractResult? _extractResult;
  int _currentUrlIndex = 0; // 当前使用的URL索引
  bool _isRetrying = false; // 是否正在重试
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 如果 episodeNumber 为 0，表示未选择集数，不初始化播放器
    if (widget.episodeNumber == 0) {
      setState(() {
        _isLoading = false;
        _isExtracting = false;
      });
      // 延迟显示集数选择器，确保界面已经渲染
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showEpisodeSelector();
        }
      });
    } else {
      _initializePlayer();
    }
    _focusNode.requestFocus();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isExtracting = true;
        _isLoading = true;
      });

      // 首先提取视频链接
      await _extractVideoUrls();
      
      // 如果有视频链接，初始化播放器
      if (_selectedVideoUrl != null) {
        await _setupVideoPlayer(_selectedVideoUrl!);
      } else {
        setState(() {
          _error = '未找到可播放的视频链接';
          _isLoading = false;
          _isExtracting = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isExtracting = false;
      });
    }
  }

  /// 提取视频链接
  Future<void> _extractVideoUrls() async {
    try {
      String? episodeUrl = _getEpisodeUrl();
      
      if (episodeUrl == null) {
        throw Exception('无法获取集数播放页面链接');
      }

      print('开始提取视频链接，集数页面: $episodeUrl');
      
      // 使用视频提取服务（启用详细日志）
      final extractor = VideoExtractor();
      final result = await extractor.extractVideoUrl(
        episodeUrl, 
        widget.sourceRule ?? _getDefaultRule(),
        enableLogging: true,
        verboseLogging: true, // 启用详细日志
      );
      
      // 始终保存提取结果（包括失败的情况）
      setState(() {
        _extractResult = result;
        _isExtracting = false;
      });
      
      if (result.success && result.videoUrls.isNotEmpty) {
        // 选择第一个视频链接
        _currentUrlIndex = 0;
        _selectedVideoUrl = result.videoUrls[_currentUrlIndex];
        print('提取成功，找到 ${result.videoUrls.length} 个视频链接');
        print('选择播放: $_selectedVideoUrl');
        if (result.videoUrls.length > 1) {
          print('备用链接: ${result.videoUrls.length - 1} 个');
        }
      } else {
        // 提取失败，但保留结果和日志
        throw Exception(result.error ?? '视频链接提取失败');
      }
      
    } catch (e) {
      print('视频链接提取失败: $e');
      setState(() {
        _error = e.toString();
        _isExtracting = false;
      });
    }
  }

  /// 获取集数播放页面URL
  String? _getEpisodeUrl() {
    // 如果anime有episodeList，从中获取对应集数的URL
    if (widget.anime.episodeList != null && widget.anime.episodeList!.isNotEmpty) {
      final episodes = widget.anime.episodeList!;
      final targetEpisode = episodes.firstWhere(
        (ep) => ep.episodeNumber == widget.episodeNumber,
        orElse: () => episodes.first,
      );
      return targetEpisode.videoUrl;
    }
    
    // 如果没有episodeList，使用anime的videoUrl作为基础URL
    return widget.anime.videoUrl;
  }

  /// 设置MediaKit播放器
  Future<void> _setupVideoPlayer(String videoUrl) async {
    try {
      print('开始初始化MediaKit播放器: $videoUrl');
      
      // 创建优化的MediaKit播放器，增强网络容错
      _player = Player(
        configuration: PlayerConfiguration(
          title: 'DimenX Player',
          vo: 'gpu', // 硬件加速
          bufferSize: 32 * 1024 * 1024, // 增加到32MB缓冲，减少网络波动影响
          logLevel: MPVLogLevel.warn, // 减少日志输出
        ),
      );
      _videoController = VideoController(_player!);
      
      // 添加播放器状态监听
      _player!.stream.error.listen((error) {
        final errorStr = error.toString();
        print('播放器错误: $errorStr');
        
        // 检查是否是网络错误（可以恢复的错误）
        if (_isNetworkError(errorStr)) {
          print('检测到网络错误，尝试恢复...');
          _handleNetworkError();
          return; // 不显示错误，尝试自动恢复
        }
        
        // 尝试切换到下一个URL
        if (!_isRetrying && _extractResult != null && 
            _extractResult!.videoUrls.length > 1 && 
            _currentUrlIndex < _extractResult!.videoUrls.length - 1) {
          
          _isRetrying = true;
          _currentUrlIndex++;
          final nextUrl = _extractResult!.videoUrls[_currentUrlIndex];
          
          print('当前URL播放失败，自动切换到备用链接 ($_currentUrlIndex/${_extractResult!.videoUrls.length})');
          print('尝试播放: $nextUrl');
          
          // 延迟一下再切换，避免太快
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _switchToUrl(nextUrl);
            }
          });
        } else {
          // 没有更多备用链接了
          setState(() {
            _error = '播放错误: $errorStr';
            _isLoading = false;
          });
          
          if (_extractResult != null && _extractResult!.videoUrls.length > 1) {
            print('所有 ${_extractResult!.videoUrls.length} 个视频链接都无法播放');
          }
        }
      });
      
      // 配置播放器选项
      await _player!.setPlaylistMode(PlaylistMode.none);
      await _player!.setAudioDevice(AudioDevice.auto());
      
      print('检测到视频URL: $videoUrl');
      
      // 根据URL类型进行优化配置
      if (videoUrl.contains('.m3u8')) {
        print('检测到HLS流媒体，使用优化配置');
        
        final uri = Uri.parse(videoUrl);
        final media = Media(
          videoUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': '${uri.scheme}://${uri.host}/',
            'Accept': '*/*',
            'Connection': 'keep-alive',
          },
          extras: {
            // 网络优化参数
            'network-timeout': '30',
            'http-reconnect': 'yes',
            'demuxer-max-bytes': '64M',
            'demuxer-max-back-bytes': '32M',
            'cache': 'yes',
            'cache-secs': '60',
            'cache-pause-initial': 'yes',
            'cache-pause-wait': '3',
          },
        );
        
        // 直接播放，减少延迟
        await _player!.open(media, play: true);
        
      } else {
        // 其他格式也添加网络优化
        await _player!.open(
          Media(
            videoUrl,
            extras: {
              'network-timeout': '30',
              'http-reconnect': 'yes',
              'cache': 'yes',
            },
          ),
          play: true,
        );
      }
      
      print('MediaKit播放器初始化成功');
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      print('MediaKit播放器初始化失败: $e');
      setState(() {
        _error = '视频播放器初始化失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 判断是否是网络错误（可恢复）
  bool _isNetworkError(String error) {
    final networkErrorPatterns = [
      'ffurl_read',
      'ffurl_write',
      'tcp',
      'Connection',
      'timeout',
      'ETIMEDOUT',
      'ECONNRESET',
    ];
    
    return networkErrorPatterns.any((pattern) => 
      error.toLowerCase().contains(pattern.toLowerCase())
    );
  }

  /// 处理网络错误，尝试恢复播放
  void _handleNetworkError() async {
    if (_player == null || _selectedVideoUrl == null) return;
    
    try {
      print('尝试恢复播放...');
      
      // 获取当前播放位置
      final position = _player!.state.position;
      
      // 等待一下让网络恢复
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 重新加载当前URL
      if (mounted && _selectedVideoUrl != null) {
        print('从位置 ${position.inSeconds}s 恢复播放');
        
        final uri = Uri.parse(_selectedVideoUrl!);
        await _player!.open(
          Media(
            _selectedVideoUrl!,
            httpHeaders: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Referer': '${uri.scheme}://${uri.host}/',
              'Accept': '*/*',
              'Connection': 'keep-alive',
            },
            extras: {
              'network-timeout': '30',
              'http-reconnect': 'yes',
              'cache': 'yes',
            },
          ),
          play: false,
        );
        
        // 跳转到之前的位置
        await _player!.seek(position);
        await _player!.play();
        
        print('播放恢复成功');
      }
    } catch (e) {
      print('恢复播放失败: $e');
    }
  }

  /// 获取默认规则
  SourceRule _getDefaultRule() {
    return SourceRule(
      id: 'default',
      name: 'default',
      version: '1.0',
      baseURL: '',
      searchURL: '',
      searchList: '',
      searchName: '',
      searchResult: '',
      chapterRoads: '',
      chapterResult: '',
      imgRoads: '',
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 显示提取日志对话框
  void _showExtractionLogs() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  const Icon(
                    Icons.article_outlined,
                    color: Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '视频提取日志',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                  ),
                ],
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 12),
              
              // 日志信息
              if (_extractResult != null) ...[
                // 提取结果摘要
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _extractResult!.success 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _extractResult!.success 
                          ? Colors.green.withOpacity(0.5)
                          : Colors.red.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _extractResult!.success ? Icons.check_circle : Icons.error,
                        color: _extractResult!.success ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _extractResult!.success ? '提取成功' : '提取失败',
                              style: TextStyle(
                                color: _extractResult!.success ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _extractResult!.success
                                  ? '找到 ${_extractResult!.videoUrls.length} 个视频链接'
                                  : _extractResult!.error ?? '未知错误',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // 视频链接列表
                if (_extractResult!.videoUrls.isNotEmpty) ...[
                  const Text(
                    '提取到的视频链接:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _extractResult!.videoUrls.asMap().entries.map((entry) {
                        final index = entry.key;
                        final url = entry.value;
                        final isCurrent = index == _currentUrlIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? Colors.blue : Colors.grey[700],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isCurrent ? '当前' : '链接 ${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.copy, size: 16),
                                    color: Colors.blue,
                                    tooltip: '复制链接',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: url));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('已复制链接 ${index + 1}'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                url,
                                style: TextStyle(
                                  color: isCurrent ? Colors.blue : Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 详细日志
                const Text(
                  '详细日志:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // 日志列表
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: _extractResult != null && _extractResult!.logs.isNotEmpty
                      ? ListView.builder(
                          itemCount: _extractResult!.logs.length,
                          itemBuilder: (context, index) {
                            final log = _extractResult!.logs[index];
                            Color logColor = Colors.white70;
                            IconData logIcon = Icons.info_outline;
                            
                            // 根据日志内容设置颜色和图标
                            if (log.contains('成功') || log.contains('完成')) {
                              logColor = Colors.green;
                              logIcon = Icons.check_circle_outline;
                            } else if (log.contains('失败') || log.contains('错误')) {
                              logColor = Colors.red;
                              logIcon = Icons.error_outline;
                            } else if (log.contains('警告')) {
                              logColor = Colors.orange;
                              logIcon = Icons.warning_amber_outlined;
                            } else if (log.contains('搜索') || log.contains('查找')) {
                              logColor = Colors.blue;
                              logIcon = Icons.search;
                            } else if (log.contains('加载') || log.contains('提取')) {
                              logColor = Colors.cyan;
                              logIcon = Icons.refresh;
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(logIcon, size: 16, color: logColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(
                                      log,
                                      style: TextStyle(
                                        color: logColor,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text(
                            '暂无日志信息',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 底部按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_extractResult != null && _extractResult!.logs.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        // 复制日志到剪贴板
                        Clipboard.setData(
                          ClipboardData(text: _extractResult!.logs.join('\n')),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('日志已复制到剪贴板'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制日志'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切换到指定URL
  Future<void> _switchToUrl(String url) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _selectedVideoUrl = url;
      });
      
      print('切换视频源: $url');
      
      if (_player == null) {
        print('播放器未初始化，无法切换');
        return;
      }
      
      // 停止当前播放
      await _player!.stop();
      
      // 加载新的视频源
      final uri = Uri.parse(url);
      await _player!.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': '${uri.scheme}://${uri.host}/',
            'Accept': '*/*',
            'Connection': 'keep-alive',
          },
        ),
      );
      
      // 自动播放
      await _player!.play();
      
      setState(() {
        _isLoading = false;
        _isRetrying = false;
      });
      
      print('✓ 视频源切换成功');
    } catch (e) {
      print('切换视频源失败: $e');
      setState(() {
        _error = '切换视频源失败: $e';
        _isLoading = false;
        _isRetrying = false;
      });
    }
  }

  /// 显示集数选择侧边栏
  void _showEpisodeSelector() {
    if (widget.anime.episodeList == null || widget.anime.episodeList!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无集数信息')),
      );
      return;
    }

    // 检查是否需要路线选择
    final needRoadSelection = widget.sourceRule != null &&
        widget.sourceRule!.roadList.isNotEmpty &&
        widget.sourceRule!.roadName.isNotEmpty;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: Material(
              elevation: 16,
              child: needRoadSelection
                  ? _EpisodeSelectorWithRoads(
                      anime: widget.anime,
                      sourceRule: widget.sourceRule!,
                      currentEpisodeNumber: widget.episodeNumber,
                    )
                  : _EpisodeSelectorSimple(
                      anime: widget.anime,
                      sourceRule: widget.sourceRule,
                      currentEpisodeNumber: widget.episodeNumber,
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // 自定义标题栏
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.anime.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.episodeNumber == 0 
                              ? '请选择集数' 
                              : '第${widget.episodeNumber}集',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 提取日志按钮
                  IconButton(
                    onPressed: _showExtractionLogs,
                    icon: const Icon(Icons.bug_report, color: Colors.white),
                    tooltip: '查看提取日志',
                  ),
                  // 全屏按钮
                  IconButton(
                    onPressed: _toggleFullScreen,
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            
            // 视频播放器
            Expanded(
              child: Container(
                color: Colors.black,
                child: _buildVideoPlayer(),
              ),
            ),
            
            // 底部控制栏
            Container(
              height: 80,
              color: const Color(0xFF2d2d2d),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 上一集按钮
                  IconButton(
                    onPressed: widget.episodeNumber > 1 ? _previousEpisode : null,
                    icon: const Icon(Icons.skip_previous),
                    color: widget.episodeNumber > 1 ? Colors.white : Colors.grey,
                  ),
                  
                  // 播放/暂停按钮
                  IconButton(
                    onPressed: widget.episodeNumber > 0 ? _togglePlayPause : null,
                    icon: Icon(
                      _player?.state.playing == true
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    color: widget.episodeNumber > 0 ? Colors.white : Colors.grey,
                    iconSize: 32,
                  ),
                  
                  // 下一集按钮
                  IconButton(
                    onPressed: widget.episodeNumber < widget.anime.episodes
                        ? _nextEpisode
                        : null,
                    icon: const Icon(Icons.skip_next),
                    color: widget.episodeNumber < widget.anime.episodes
                        ? Colors.white
                        : Colors.grey,
                  ),
                  
                  const Spacer(),
                  
                  // 集数选择按钮
                  IconButton(
                    onPressed: _showEpisodeSelector,
                    icon: const Icon(Icons.list),
                    color: Colors.white,
                    tooltip: '集数选择',
                  ),
                  
                  // 快退按钮
                  IconButton(
                    onPressed: widget.episodeNumber > 0 ? _seekBackward : null,
                    icon: const Icon(Icons.replay_10),
                    color: widget.episodeNumber > 0 ? Colors.white : Colors.grey,
                  ),
                  
                  // 快进按钮
                  IconButton(
                    onPressed: widget.episodeNumber > 0 ? _seekForward : null,
                    icon: const Icon(Icons.forward_10),
                    color: widget.episodeNumber > 0 ? Colors.white : Colors.grey,
                  ),
                  
                  // 音量控制
                  IconButton(
                    onPressed: _toggleMute,
                    icon: Icon(
                      (_player?.state.volume ?? 0.0) > 0
                          ? Icons.volume_up
                          : Icons.volume_off,
                    ),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // 如果未选择集数，显示黑屏
    if (widget.episodeNumber == 0) {
      return const SizedBox.shrink();
    }
    
    if (_isExtracting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在提取视频链接...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在初始化播放器...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '视频加载失败',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isLoading = true;
                            _isExtracting = true;
                          });
                          _initializePlayer();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () {
                          _showExtractionLogs();
                        },
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('查看日志'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_videoController != null) {
      return Video(controller: _videoController!);
    }

    return const Center(
      child: Text(
        '视频播放器初始化失败',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _player != null) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          _togglePlayPause();
          break;
        case LogicalKeyboardKey.arrowLeft:
          _seekBackward();
          break;
        case LogicalKeyboardKey.arrowRight:
          _seekForward();
          break;
        case LogicalKeyboardKey.arrowUp:
          _volumeUp();
          break;
        case LogicalKeyboardKey.arrowDown:
          _volumeDown();
          break;
        case LogicalKeyboardKey.keyF:
          _toggleFullScreen();
          break;
      }
    }
  }

  void _togglePlayPause() {
    if (_player?.state.playing == true) {
      _player?.pause();
    } else {
      _player?.play();
    }
    setState(() {});
  }

  /// 快退10秒
  void _seekBackward() {
    final currentPosition = _player?.state.position ?? Duration.zero;
    final newPosition = currentPosition - const Duration(seconds: 10);
    _player?.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  /// 快进10秒
  void _seekForward() {
    final currentPosition = _player?.state.position ?? Duration.zero;
    final duration = _player?.state.duration ?? Duration.zero;
    final newPosition = currentPosition + const Duration(seconds: 10);
    _player?.seek(newPosition < duration ? newPosition : duration);
  }

  /// 音量增加
  void _volumeUp() {
    final currentVolume = _player?.state.volume ?? 0.0;
    final newVolume = (currentVolume + 10.0).clamp(0.0, 100.0);
    _player?.setVolume(newVolume);
  }

  /// 音量减少
  void _volumeDown() {
    final currentVolume = _player?.state.volume ?? 0.0;
    final newVolume = (currentVolume - 10.0).clamp(0.0, 100.0);
    _player?.setVolume(newVolume);
  }

  void _toggleMute() {
    final currentVolume = _player?.state.volume ?? 0.0;
    _player?.setVolume(currentVolume > 0 ? 0.0 : 100.0);
    setState(() {});
  }

  void _toggleFullScreen() {
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }
  }

  void _previousEpisode() {
    if (widget.episodeNumber > 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OptimizedVideoPlayerScreen(
            anime: widget.anime,
            episodeNumber: widget.episodeNumber - 1,
          ),
        ),
      );
    }
  }

  void _nextEpisode() {
    if (widget.episodeNumber < widget.anime.episodes) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OptimizedVideoPlayerScreen(
            anime: widget.anime,
            episodeNumber: widget.episodeNumber + 1,
          ),
        ),
      );
    }
  }
}


// 简单的集数选择器（无路线）
class _EpisodeSelectorSimple extends StatelessWidget {
  final Anime anime;
  final SourceRule? sourceRule;
  final int currentEpisodeNumber;

  const _EpisodeSelectorSimple({
    required this.anime,
    required this.sourceRule,
    required this.currentEpisodeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '选择集数',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // 集数列表
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: anime.episodeList!.length,
              itemBuilder: (context, index) {
                final episode = anime.episodeList![index];
                final isCurrentEpisode = episode.episodeNumber == currentEpisodeNumber;
                
                return Material(
                  color: isCurrentEpisode
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pop(context);
                      if (!isCurrentEpisode) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OptimizedVideoPlayerScreen(
                              anime: anime,
                              episodeNumber: episode.episodeNumber,
                              sourceRule: sourceRule,
                            ),
                          ),
                        );
                      }
                    },
                    child: Center(
                      child: Text(
                        '第${episode.episodeNumber}集',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrentEpisode
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isCurrentEpisode
                              ? Colors.white
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 带路线选择的集数选择器
class _EpisodeSelectorWithRoads extends StatefulWidget {
  final Anime anime;
  final SourceRule sourceRule;
  final int currentEpisodeNumber;

  const _EpisodeSelectorWithRoads({
    required this.anime,
    required this.sourceRule,
    required this.currentEpisodeNumber,
  });

  @override
  State<_EpisodeSelectorWithRoads> createState() => _EpisodeSelectorWithRoadsState();
}

class _EpisodeSelectorWithRoadsState extends State<_EpisodeSelectorWithRoads> {
  bool _isLoadingRoads = true;
  List<String> _roads = [];
  int? _selectedRoadIndex;
  bool _isLoadingEpisodes = false;
  Anime? _animeWithEpisodes;

  @override
  void initState() {
    super.initState();
    _loadRoads();
  }

  Future<void> _loadRoads() async {
    try {
      final detailService = AnimeDetailService();
      final roads = await detailService.extractRoads(
        widget.anime.detailUrl,
        widget.sourceRule,
      );
      
      if (mounted) {
        setState(() {
          _roads = roads;
          _isLoadingRoads = false;
        });
      }
    } catch (e) {
      print('加载路线失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingRoads = false;
        });
      }
    }
  }

  Future<void> _selectRoad(int roadIndex) async {
    setState(() {
      _selectedRoadIndex = roadIndex;
      _isLoadingEpisodes = true;
    });

    try {
      final detailService = AnimeDetailService();
      final animeWithEpisodes = await detailService.fetchAnimeDetailWithRoad(
        widget.anime,
        widget.sourceRule,
        roadIndex: roadIndex,
      );
      
      if (mounted) {
        setState(() {
          _animeWithEpisodes = animeWithEpisodes;
          _isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      print('加载集数失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载集数失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedRoadIndex == null ? '选择路线' : '选择集数',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_selectedRoadIndex != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedRoadIndex = null;
                        _animeWithEpisodes = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '返回路线选择',
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // 内容区域
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // 加载路线中
    if (_isLoadingRoads) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载路线...'),
          ],
        ),
      );
    }

    // 路线加载失败
    if (_roads.isEmpty) {
      return const Center(
        child: Text('未找到可用路线'),
      );
    }

    // 显示路线选择
    if (_selectedRoadIndex == null) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _roads.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.route),
              title: Text(
                _roads[index],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectRoad(index),
            ),
          );
        },
      );
    }

    // 加载集数中
    if (_isLoadingEpisodes) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载集数...'),
          ],
        ),
      );
    }

    // 显示集数列表
    if (_animeWithEpisodes != null && 
        _animeWithEpisodes!.episodeList != null &&
        _animeWithEpisodes!.episodeList!.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _animeWithEpisodes!.episodeList!.length,
        itemBuilder: (context, index) {
          final episode = _animeWithEpisodes!.episodeList![index];
          final isCurrentEpisode = episode.episodeNumber == widget.currentEpisodeNumber;
          
          return Material(
            color: isCurrentEpisode
                ? Theme.of(context).primaryColor
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.pop(context);
                if (!isCurrentEpisode) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OptimizedVideoPlayerScreen(
                        anime: _animeWithEpisodes!,
                        episodeNumber: episode.episodeNumber,
                        sourceRule: widget.sourceRule,
                      ),
                    ),
                  );
                }
              },
              child: Center(
                child: Text(
                  '第${episode.episodeNumber}集',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrentEpisode
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isCurrentEpisode
                        ? Colors.white
                        : null,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // 集数加载失败
    return const Center(
      child: Text('未找到可播放的集数'),
    );
  }
}
