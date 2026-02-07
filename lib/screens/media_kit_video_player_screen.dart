import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../services/video_extractor.dart';

class MediaKitVideoPlayerScreen extends StatefulWidget {
  final Anime anime;
  final int episodeNumber;
  final SourceRule? sourceRule;

  const MediaKitVideoPlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.sourceRule,
  });

  @override
  State<MediaKitVideoPlayerScreen> createState() => _MediaKitVideoPlayerScreenState();
}

class _MediaKitVideoPlayerScreenState extends State<MediaKitVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;
  
  bool _isLoading = true;
  bool _isExtracting = false;
  String? _error;
  String? _selectedVideoUrl;
  VideoExtractResult? _extractResult;
  int _currentUrlIndex = 0; // 当前使用的URL索引
  bool _isRetrying = false; // 是否正在重试

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: PlayerConfiguration(
        // 启用硬件解码和GPU渲染
        vo: 'gpu',
        
        // 大幅优化缓冲设置
        bufferSize: 64 * 1024 * 1024, // 64MB缓冲（增加一倍）
        
        // 设置标题
        title: '${widget.anime.title} - 第${widget.episodeNumber}集',
        
        // 启用日志以便调试
        logLevel: MPVLogLevel.info,
        
        
        // 其他优化选项
        ready: () {
          print('MediaKit播放器配置完成');
        },
      ),
    );
    _videoController = VideoController(_player);
    _initializePlayer();
  }


  @override
  void dispose() {
    _player.dispose();
    
    // 清理WebView提取器资源
    _cleanupExtractor();
    
    super.dispose();
  }
  
  /// 清理提取器资源
  void _cleanupExtractor() {
    try {
      // 异步清理，不阻塞dispose
      Future.microtask(() async {
        final extractor = VideoExtractor();
        await extractor.stopExtraction();
        print('播放器退出：视频提取器资源已清理');
      });
    } catch (e) {
      print('播放器退出：清理视频提取器资源失败: $e');
    }
  }

  /// 初始化播放器
  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _isExtracting = true;
        _error = null;
      });

      // 提取视频链接
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
        throw Exception('无法获取集数播放页面URL');
      }

      final extractor = VideoExtractor();
      final rule = widget.sourceRule ?? _getDefaultRule();
      
      final result = await extractor.extractVideoUrl(episodeUrl, rule);
      
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

  /// 获取默认规则（当没有提供sourceRule时）
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

  /// 设置视频播放器
  Future<void> _setupVideoPlayer(String videoUrl) async {
    try {
      print('开始初始化MediaKit播放器: $videoUrl');
      
      // 设置播放源，添加网络优化选项和缓冲策略
      await _player.open(
        Media(
          videoUrl, 
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': _getRefererUrl(),
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Accept-Encoding': 'identity', // 避免压缩以减少解码开销
            'Connection': 'keep-alive',
            'Cache-Control': 'no-cache',
          },
          // 添加额外的媒体选项
          extras: {
            'network-timeout': '30',
            'http-reconnect': 'yes',
            'cache': 'yes',
            'cache-secs': '60',
          },
        ),
      );
      
      // 监听播放器状态变化
      _player.stream.buffering.listen((buffering) {
        if (buffering) {
          print('播放器缓冲中...');
        } else {
          print('播放器缓冲完成');
        }
      });
      
      // 监听播放器错误
      _player.stream.error.listen((error) {
        print('播放器错误: $error');
        
        // 尝试切换到下一个URL
        if (!_isRetrying && _extractResult != null && 
            _extractResult!.videoUrls.length > 1 && 
            _currentUrlIndex < _extractResult!.videoUrls.length - 1) {
          
          _isRetrying = true;
          _currentUrlIndex++;
          final nextUrl = _extractResult!.videoUrls[_currentUrlIndex];
          
          print('⚠️ 当前URL播放失败，自动切换到备用链接 ($_currentUrlIndex/${_extractResult!.videoUrls.length})');
          print('尝试播放: $nextUrl');
          
          // 延迟一下再切换，避免太快
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _switchToUrl(nextUrl);
            }
          });
        } else {
          // 没有更多备用链接了
          if (mounted) {
            setState(() {
              _error = '播放错误: $error';
              _isLoading = false;
            });
            
            if (_extractResult != null && _extractResult!.videoUrls.length > 1) {
              print('❌ 所有 ${_extractResult!.videoUrls.length} 个视频链接都无法播放');
            }
          }
        }
      });
      
      setState(() {
        _isLoading = false;
      });
      
      print('MediaKit播放器初始化成功');
    } catch (e) {
      print('MediaKit播放器初始化失败: $e');
      setState(() {
        _error = '视频播放器初始化失败: $e';
        _isLoading = false;
      });
    }
  }
  
  /// 获取Referer URL
  String _getRefererUrl() {
    if (widget.sourceRule != null) {
      return widget.sourceRule!.baseURL;
    }
    return 'https://www.google.com/';
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
      
      // 停止当前播放
      await _player.stop();
      
      // 加载新的视频源
      await _player.open(
        Media(
          url,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': _getRefererUrl(),
          },
        ),
      );
      
      // 自动播放
      await _player.play();
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 视频播放区域
          Expanded(
            child: _buildVideoPlayer(),
          ),
          
          // 控制栏
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isExtracting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              '正在提取视频链接...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_extractResult?.logs.isNotEmpty == true)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      '提取日志:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...(_extractResult!.logs.take(3).map((log) => Text(
                      log,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ))),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              '正在初始化播放器...',
              style: TextStyle(color: Colors.white),
            ),
            if (_selectedVideoUrl != null) ...[
              const SizedBox(height: 8),
              Text(
                '视频链接: ${_selectedVideoUrl!.length > 50 ? "${_selectedVideoUrl!.substring(0, 50)}..." : _selectedVideoUrl!}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
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

    // 显示视频播放器
    return Video(controller: _videoController);
  }

  Widget _buildControlBar() {
    return Container(
      height: 80,
      color: Colors.black87,
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
          
          // 动漫信息
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '第${widget.episodeNumber}集',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // 上一集按钮
          IconButton(
            onPressed: widget.episodeNumber > 1 ? _previousEpisode : null,
            icon: const Icon(Icons.skip_previous),
            color: widget.episodeNumber > 1 ? Colors.white : Colors.grey,
          ),
          
          // 播放/暂停按钮
          StreamBuilder<bool>(
            stream: _player.stream.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return IconButton(
                onPressed: () {
                  if (isPlaying) {
                    _player.pause();
                  } else {
                    _player.play();
                  }
                },
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                color: Colors.white,
                iconSize: 32,
              );
            },
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
          
          // 提取日志按钮
          IconButton(
            onPressed: _showExtractionLogs,
            icon: const Icon(Icons.bug_report),
            color: Colors.white,
            tooltip: '查看提取日志',
          ),
          
          // 音量控制
          StreamBuilder<double>(
            stream: _player.stream.volume,
            builder: (context, snapshot) {
              final volume = snapshot.data ?? 1.0;
              return IconButton(
                onPressed: () {
                  _player.setVolume(volume > 0 ? 0.0 : 1.0);
                },
                icon: Icon(
                  volume > 0 ? Icons.volume_up : Icons.volume_off,
                ),
                color: Colors.white,
              );
            },
          ),
          
          // 全屏按钮
          IconButton(
            onPressed: _toggleFullScreen,
            icon: const Icon(Icons.fullscreen),
            color: Colors.white,
          ),
        ],
      ),
    );
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

  void _previousEpisode() {
    if (widget.episodeNumber > 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MediaKitVideoPlayerScreen(
            anime: widget.anime,
            episodeNumber: widget.episodeNumber - 1,
            sourceRule: widget.sourceRule,
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
          builder: (context) => MediaKitVideoPlayerScreen(
            anime: widget.anime,
            episodeNumber: widget.episodeNumber + 1,
            sourceRule: widget.sourceRule,
          ),
        ),
      );
    }
  }
}
