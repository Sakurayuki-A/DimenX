import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../services/video_extractor.dart';

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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
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
      
      // 使用视频提取服务
      final extractor = VideoExtractor();
      final result = await extractor.extractVideoUrl(
        episodeUrl, 
        widget.sourceRule ?? _getDefaultRule(),
      );
      
      setState(() {
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

  /// 设置MediaKit播放器
  Future<void> _setupVideoPlayer(String videoUrl) async {
    try {
      print('开始初始化MediaKit播放器: $videoUrl');
      
      // 创建优化的MediaKit播放器
      _player = Player(
        configuration: PlayerConfiguration(
          title: 'DimenX Player',
          vo: 'gpu', // 硬件加速
          bufferSize: 16 * 1024 * 1024, // 16MB缓冲，优化快进响应
          logLevel: MPVLogLevel.warn, // 减少日志输出
        ),
      );
      _videoController = VideoController(_player!);
      
      // 添加播放器状态监听
      _player!.stream.error.listen((error) {
        print('播放器错误: $error');
        setState(() {
          _error = '播放错误: $error';
          _isLoading = false;
        });
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
        );
        
        // 直接播放，减少延迟
        await _player!.open(media, play: true);
        
      } else {
        // 其他格式直接播放
        await _player!.open(Media(videoUrl), play: true);
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
                          '第${widget.episodeNumber}集',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _player?.state.playing == true
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    color: Colors.white,
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
                  
                  // 快退按钮
                  IconButton(
                    onPressed: _seekBackward,
                    icon: const Icon(Icons.replay_10),
                    color: Colors.white,
                  ),
                  
                  // 快进按钮
                  IconButton(
                    onPressed: _seekForward,
                    icon: const Icon(Icons.forward_10),
                    color: Colors.white,
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
            ],
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
