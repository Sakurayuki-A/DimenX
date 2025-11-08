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
        _selectedVideoUrl = result.videoUrls.first;
        print('提取成功，找到 ${result.videoUrls.length} 个视频链接');
        print('选择播放: $_selectedVideoUrl');
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
        if (mounted) {
          setState(() {
            _error = '播放错误: $error';
            _isLoading = false;
          });
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
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
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
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                        _isExtracting = true;
                      });
                      _initializePlayer();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('重试'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ],
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
