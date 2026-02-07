import 'extraction_logger.dart';

/// URL检测和验证器
class UrlDetector {
  final ExtractionLogger logger;

  UrlDetector({required this.logger});

  /// 检查是否为视频URL
  bool isVideoUrl(String url) {
    if (url.isEmpty) return false;

    final lowerUrl = url.toLowerCase();

    // 排除明显不是视频的文件
    if (_shouldExclude(lowerUrl)) return false;

    // 检查视频文件扩展名
    if (_hasVideoExtension(lowerUrl)) return true;

    // 检查视频路径模式
    if (_hasVideoPathPattern(lowerUrl)) return true;

    // 检查视频CDN域名
    if (_hasVideoCdnDomain(lowerUrl)) return true;

    // 检查视频查询参数
    if (_hasVideoQueryParams(lowerUrl)) return true;

    return false;
  }

  /// 检查是否为播放器iframe链接
  bool isPlayerIframeUrl(String url) {
    final lowerUrl = url.toLowerCase();

    // 播放器路径特征
    final playerPatterns = [
      '/player/', '/play/', '/iframe/', '/embed/',
      '/vip/', '/jx/', '/parse/', '/api/',  // 新增：解析服务
      'player.php', 'play.php', 'iframe.php', 'embed.php',
      'ec.php', 'jx.php', 'parse.php',
    ];

    for (final pattern in playerPatterns) {
      if (lowerUrl.contains(pattern)) {
        // 确保不是视频文件本身
        if (!lowerUrl.contains('.m3u8') &&
            !lowerUrl.contains('.mp4') &&
            !lowerUrl.contains('.flv')) {
          return true;
        }
      }
    }

    // 检查域名特征（解析服务通常有特定域名）
    final parserDomains = [
      'jx.', 'parse.', 'player.', 'api.', 'vip.',
    ];
    
    for (final domain in parserDomains) {
      if (lowerUrl.contains(domain) && lowerUrl.contains('?url=')) {
        return true;
      }
    }

    return false;
  }

  /// 检查是否应该拦截脚本
  bool shouldBlockScript(String url) {
    if (url.isEmpty) return false;

    final lowerUrl = url.toLowerCase();

    // 反调试脚本列表
    final blockedScripts = [
      'devtools-detector.js', 'devtools-detect.js', 'anti-devtools.js',
      'debugger-detector.js', 'console-ban.js', 'disable-devtools.js',
      'anti-debug.js', 'devtools-blocker.js', 'f12-disable.js',
    ];

    for (final script in blockedScripts) {
      if (lowerUrl.contains(script)) return true;
    }

    // 反调试代码特征检测
    final antiDebugPatterns = [
      r'debugger[;\s]', r'console\.clear', r'setinterval.*debugger',
      r'anti.*debug', r'disable.*f12', r'block.*devtools',
    ];

    for (final pattern in antiDebugPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerUrl)) {
        return true;
      }
    }

    return false;
  }

  /// 对视频URL进行优先级排序
  List<String> prioritizeUrls(List<String> urls) {
    if (urls.isEmpty) return urls;

    final prioritized = <String>[];
    final direct = <String>[];

    for (final url in urls) {
      if (_isPlayerUrl(url)) {
        prioritized.add(url);
      } else {
        direct.add(url);
      }
    }

    final result = [...prioritized, ...direct];

    if (result.isNotEmpty && result.first != urls.first) {
      logger.info('URL优先级排序: 播放器URL ${prioritized.length}个, 直接URL ${direct.length}个');
    }

    return result;
  }

  /// 提取代理URL中的真实视频链接
  String? extractRealVideoUrl(String proxyUrl) {
    if (!proxyUrl.contains('?url=') && !proxyUrl.contains('&url=')) {
      return null;
    }

    final urlMatch = RegExp(r'[?&]url=([^&]+)').firstMatch(proxyUrl);
    if (urlMatch != null) {
      try {
        final decoded = Uri.decodeComponent(urlMatch.group(1)!);
        if (isVideoUrl(decoded)) {
          return decoded;
        }
      } catch (e) {
        logger.error('解析代理URL失败: $e');
      }
    }

    return null;
  }

  // ===== 私有辅助方法 =====

  bool _shouldExclude(String url) {
    final excludePatterns = [
      r'\.(jpg|jpeg|png|gif|webp|svg|ico|css|js|html|htm|txt|xml|json)(\?|$)',
      r'/(api|ajax|json|xml|search|login|register)/',
      r'vodplay/\d+-\d+-\d+\.html$',
      r'voddetail/\d+\.html$',
      r'google-analytics\.com',  // 排除 Google Analytics
      r'googletagmanager\.com',  // 排除 Google Tag Manager
      r'/\d{7,}\.ts$',  // 排除 .ts 分片文件（如 0000000.ts）
    ];

    for (final pattern in excludePatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(url)) {
        return true;
      }
    }

    return false;
  }

  bool _hasVideoExtension(String url) {
    final videoExtensions = [
      '.m3u8', '.mp4', '.flv', '.ts', '.mkv', '.avi', '.webm', '.mov', '.wmv'
    ];

    for (final ext in videoExtensions) {
      if (url.contains(ext)) return true;
    }

    return false;
  }

  bool _hasVideoPathPattern(String url) {
    final videoPatterns = [
      r'/hls/', r'/video/', r'/stream/', r'/media/', r'/live/',
      r'playlist\.m3u8', r'index\.m3u8', r'master\.m3u8',
      r'blob:', r'data:video/',
      r'/tos/', // 字节跳动TOS存储
    ];

    for (final pattern in videoPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(url)) {
        return true;
      }
    }

    return false;
  }

  bool _hasVideoCdnDomain(String url) {
    // 字节跳动CDN - 特殊处理（只要有/tos/或tos-就认为是视频）
    final bytedanceCdns = [
      'toutiao50.com', 'toutiao.com', 'toutiaocdn.com',
      'snssdk.com', 'amemv.com',
      'xiguavod.com', 'bdxiguavod.com',
      'bytecdn.cn', 'bytedance.com', 'bytedns.net',
      'bytetos.com', 'bytedance.net', // 新增：字节跳动TOS存储域名
      'byteimg.com', 'pstatp.com', // 新增：字节跳动图片/视频CDN
    ];
    
    for (final cdn in bytedanceCdns) {
      if (url.contains(cdn)) {
        // 字节跳动CDN只要包含/tos/、tos-、/video/就是视频
        if (url.contains('/tos/') || 
            url.contains('tos-') || 
            url.contains('/video/') ||
            url.contains('imcloud-file')) { // 新增：imcloud文件存储
          logger.debug('通过字节跳动CDN识别视频: $cdn');
          return true;
        }
      }
    }
    
    // 其他CDN需要更严格的路径匹配
    final otherCdnDomains = [
      'alicdn.com', 'aliyuncs.com',
      'qcloud.com', 'myqcloud.com',
      'cloudfront.net', 'amazonaws.com',
    ];

    for (final domain in otherCdnDomains) {
      if (url.contains(domain)) {
        final videoPathPatterns = [
          '/video/', '/vod/', '/stream/', '/media/', '/hls/', '/live/'
        ];

        for (final path in videoPathPatterns) {
          if (url.contains(path)) {
            logger.debug('通过CDN域名+路径识别视频: $domain + $path');
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _hasVideoQueryParams(String url) {
    final videoQueryParams = [
      'mime_type=video', 'video_mp4', 'video_m3u8', 'video_flv',
      'video_', 'quality=', 'bitrate=', 'br=', 'bt=',
      'cdn_type=', 'dy_q=',
    ];

    for (final param in videoQueryParams) {
      if (url.contains(param)) {
        logger.debug('通过查询参数识别视频: $param');
        return true;
      }
    }

    return false;
  }

  bool _isPlayerUrl(String url) {
    return url.contains('/player/') ||
        url.contains('/play/') ||
        url.contains('/iframe/') ||
        url.contains('player.php') ||
        url.contains('play.php') ||
        url.contains('?url=') ||
        url.contains('&url=');
  }
}
