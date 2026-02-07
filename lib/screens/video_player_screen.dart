import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/anime.dart';
import '../models/source_rule.dart';
import '../services/video_extractor.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Anime anime;
  final int episodeNumber;
  final SourceRule? sourceRule;

  const VideoPlayerScreen({
    super.key,
    required this.anime,
    required this.episodeNumber,
    this.sourceRule,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  // 播放器相关
  Player? _player;
  VideoController? _videoController;
  
  // 状态管理
  bool _isLoading = true;
  bool _isExtracting = true;
  bool _isControlsVisible = true;
  bool _isFullscreen = false;
  String? _error;
  String? _selectedVideoUrl;
  VideoExtractResult? _extractResult;
  
  // 播放状态
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 1.0;
  bool _isMuted = false;
  double _playbackSpeed = 1.0;
  
  // UI控制
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;
  final FocusNode _focusNode = FocusNode();
  
  // 定时器
  Timer? _hideControlsTimer;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializePlayer();
    _focusNode.requestFocus();
  }

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _controlsAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controlsAnimationController,
      curve: Curves.easeInOut,
    ));
    _controlsAnimationController.forward();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _isExtracting = true;
        _error = null;
      });

      // 提取视频链接
      await _extractVideoUrls();
      
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
        _selectedVideoUrl = result.videoUrls.first;
        print('提取成功，找到 ${result.videoUrls.length} 个视频链接');
      } else {
        throw Exception(result.error ?? '视频链接提取失败');
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isExtracting = false;
      });
    }
  }

  String? _getEpisodeUrl() {
    if (widget.anime.episodeList != null && widget.anime.episodeList!.isNotEmpty) {
      final episodes = widget.anime.episodeList!;
      final targetEpisode = episodes.firstWhere(
        (ep) => ep.episodeNumber == widget.episodeNumber,
        orElse: () => episodes.first,
      );
      return targetEpisode.videoUrl;
    }
    return widget.anime.videoUrl;
  }

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

  Future<void> _setupVideoPlayer(String videoUrl) async {
    try {
      print('初始化新一代视频播放器: $videoUrl');
      
      _player = Player(
        configuration: PlayerConfiguration(
          title: '${widget.anime.title} - 第${widget.episodeNumber}集',
          vo: 'gpu', // 使用GPU渲染
          bufferSize: 128 * 1024 * 1024, // 128MB缓冲区
          logLevel: MPVLogLevel.warn,
          
          // 网络优化
          ready: () {
            print('播放器配置完成');
          },
        ),
      );
      
      _videoController = VideoController(_player!);
      
      // 设置播放器选项
      await _player!.setPlaylistMode(PlaylistMode.none);
      await _player!.setAudioDevice(AudioDevice.auto());
      
      // 监听播放器状态
      _setupPlayerListeners();
      
      // 打开媒体文件
      final uri = Uri.parse(videoUrl);
      await _player!.open(
        Media(
          videoUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': '${uri.scheme}://${uri.host}/',
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Connection': 'keep-alive',
            'Cache-Control': 'no-cache',
          },
          extras: {
            'network-timeout': '30',
            'http-reconnect': 'yes',
            'cache': 'yes',
            'cache-secs': '120',
            'demuxer-max-bytes': '150M',
            'demuxer-max-back-bytes': '75M',
          },
        ),
        play: false, // 不自动播放，等待用户操作
      );
      
      setState(() {
        _isLoading = false;
      });
      
      // 启动控制栏自动隐藏定时器
      _startHideControlsTimer();
      
      print('新一代视频播放器初始化成功');
    } catch (e) {
      print('播放器初始化失败: $e');
      setState(() {
        _error = '视频播放器初始化失败: $e';
        _isLoading = false;
      });
    }
  }

  void _setupPlayerListeners() {
    // 播放状态监听
    _player!.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
    
    // 位置监听
    _player!.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    
    // 时长监听
    _player!.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
    
    // 音量监听
    _player!.stream.volume.listen((volume) {
      if (mounted) {
        setState(() {
          _volume = volume / 100.0;
        });
      }
    });
    
    // 错误监听
    _player!.stream.error.listen((error) {
      print('播放器错误: $error');
      if (mounted) {
        setState(() {
          _error = '播放错误: $error';
        });
      }
    });
    
    // 缓冲监听
    _player!.stream.buffering.listen((buffering) {
      print(buffering ? '缓冲中...' : '缓冲完成');
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (_isPlaying && mounted) {
        _hideControls();
      }
    });
  }

  void _showControls() {
    if (!_isControlsVisible) {
      setState(() {
        _isControlsVisible = true;
      });
      _controlsAnimationController.forward();
    }
    _startHideControlsTimer();
  }

  void _hideControls() {
    if (_isControlsVisible) {
      setState(() {
        _isControlsVisible = false;
      });
      _controlsAnimationController.reverse();
    }
    _hideControlsTimer?.cancel();
  }

  void _toggleControls() {
    if (_isControlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _positionTimer?.cancel();
    _controlsAnimationController.dispose();
    _player?.dispose();
    _focusNode.dispose();
    
    // 清理视频提取器资源
    Future.microtask(() async {
      try {
        final extractor = VideoExtractor();
        await extractor.stopExtraction();
      } catch (e) {
        print('清理视频提取器失败: $e');
      }
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // 视频播放器主体
            _buildVideoPlayer(),
            
            // 控制栏覆盖层
            _buildControlsOverlay(),
            
            // 加载指示器
            if (_isLoading || _isExtracting) _buildLoadingOverlay(),
            
            // 错误显示
            if (_error != null) _buildErrorOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTap: _togglePlayPause,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: _videoController != null && !_isLoading && _error == null
            ? Video(
                controller: _videoController!,
                fit: BoxFit.contain,
              )
            : Container(),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _controlsAnimation.value,
          child: _isControlsVisible ? _buildControls() : Container(),
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        children: [
          // 顶部控制栏
          _buildTopControls(),
          
          // 中间播放按钮
          Expanded(
            child: Center(
              child: _buildCenterPlayButton(),
            ),
          ),
          
          // 底部控制栏
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          
          const SizedBox(width: 16),
          
          // 标题信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.anime.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '第${widget.episodeNumber}集',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // 播放速度
          _buildSpeedControl(),
          
          const SizedBox(width: 8),
          
          // 全屏按钮
          IconButton(
            onPressed: _toggleFullScreen,
            icon: Icon(
              _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPlayButton() {
    if (_isPlaying) return Container();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: _togglePlayPause,
        icon: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 进度条
          _buildProgressBar(),
          
          const SizedBox(height: 16),
          
          // 控制按钮行
          Row(
            children: [
              // 播放/暂停
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              
              // 时间显示
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              
              const Spacer(),
              
              // 上一集
              IconButton(
                onPressed: widget.episodeNumber > 1 ? _previousEpisode : null,
                icon: Icon(
                  Icons.skip_previous,
                  color: widget.episodeNumber > 1 ? Colors.white : Colors.grey,
                  size: 24,
                ),
              ),
              
              // 快退
              IconButton(
                onPressed: _seekBackward,
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 24),
              ),
              
              // 快进
              IconButton(
                onPressed: _seekForward,
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 24),
              ),
              
              // 下一集
              IconButton(
                onPressed: widget.episodeNumber < widget.anime.episodes ? _nextEpisode : null,
                icon: Icon(
                  Icons.skip_next,
                  color: widget.episodeNumber < widget.anime.episodes ? Colors.white : Colors.grey,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 音量控制
              _buildVolumeControl(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration.inMilliseconds > 0 
        ? _position.inMilliseconds / _duration.inMilliseconds 
        : 0.0;
    
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.red,
        inactiveTrackColor: Colors.white.withOpacity(0.3),
        thumbColor: Colors.red,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackHeight: 4,
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: (value) {
          final newPosition = Duration(
            milliseconds: (value * _duration.inMilliseconds).round(),
          );
          _player?.seek(newPosition);
        },
        onChangeStart: (value) {
          _hideControlsTimer?.cancel();
        },
        onChangeEnd: (value) {
          _startHideControlsTimer();
        },
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggleMute,
          icon: Icon(
            _isMuted || _volume == 0 ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
            size: 24,
          ),
        ),
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 2,
            ),
            child: Slider(
              value: _isMuted ? 0.0 : _volume,
              onChanged: (value) {
                _setVolume(value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedControl() {
    return PopupMenuButton<double>(
      icon: const Icon(Icons.speed, color: Colors.white),
      onSelected: (speed) {
        _setPlaybackSpeed(speed);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0.5, child: Text('0.5x')),
        const PopupMenuItem(value: 0.75, child: Text('0.75x')),
        const PopupMenuItem(value: 1.0, child: Text('1.0x')),
        const PopupMenuItem(value: 1.25, child: Text('1.25x')),
        const PopupMenuItem(value: 1.5, child: Text('1.5x')),
        const PopupMenuItem(value: 2.0, child: Text('2.0x')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 24),
            Text(
              _isExtracting ? '正在提取视频链接...' : '正在初始化播放器...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            if (_isExtracting && _extractResult?.logs.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      '提取日志:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_extractResult!.logs.take(3).map((log) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        log,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
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
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                      _initializePlayer();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('返回'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 控制方法
  void _togglePlayPause() {
    if (_player != null) {
      if (_isPlaying) {
        _player!.pause();
      } else {
        _player!.play();
      }
      _showControls();
    }
  }

  void _seekBackward() {
    if (_player != null) {
      final newPosition = _position - const Duration(seconds: 10);
      _player!.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
      _showControls();
    }
  }

  void _seekForward() {
    if (_player != null) {
      final newPosition = _position + const Duration(seconds: 10);
      _player!.seek(newPosition < _duration ? newPosition : _duration);
      _showControls();
    }
  }

  void _setVolume(double volume) {
    if (_player != null) {
      _player!.setVolume(volume * 100);
      setState(() {
        _volume = volume;
        _isMuted = volume == 0;
      });
    }
  }

  void _toggleMute() {
    if (_player != null) {
      if (_isMuted) {
        _player!.setVolume(_volume * 100);
        setState(() {
          _isMuted = false;
        });
      } else {
        _player!.setVolume(0);
        setState(() {
          _isMuted = true;
        });
      }
    }
  }

  void _setPlaybackSpeed(double speed) {
    if (_player != null) {
      _player!.setRate(speed);
      setState(() {
        _playbackSpeed = speed;
      });
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _previousEpisode() {
    if (widget.episodeNumber > 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
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
          builder: (context) => VideoPlayerScreen(
            anime: widget.anime,
            episodeNumber: widget.episodeNumber + 1,
            sourceRule: widget.sourceRule,
          ),
        ),
      );
    }
  }

  // 键盘事件处理
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
          _setVolume((_volume + 0.1).clamp(0.0, 1.0));
          break;
        case LogicalKeyboardKey.arrowDown:
          _setVolume((_volume - 0.1).clamp(0.0, 1.0));
          break;
        case LogicalKeyboardKey.keyF:
          _toggleFullScreen();
          break;
        case LogicalKeyboardKey.keyM:
          _toggleMute();
          break;
        case LogicalKeyboardKey.escape:
          if (_isFullscreen) {
            _toggleFullScreen();
          } else {
            Navigator.pop(context);
          }
          break;
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
