// AnimeHUBX 视频监听脚本
// 监听页面中的视频链接

(function() {
  console.log('AnimeHUBX: 注入视频监听脚本');
  
  // 视频URL检测函数
  function isVideoUrl(url) {
    if (!url || typeof url !== 'string') return false;
    
    const lowerUrl = url.toLowerCase();
    
    // 排除非视频文件
    const excludeExts = ['.jpg', '.jpeg', '.png', '.gif', '.css', '.js', '.html'];
    for (const ext of excludeExts) {
      if (lowerUrl.includes(ext)) return false;
    }
    
    // 检查视频文件扩展名
    const videoExts = ['.m3u8', '.mp4', '.flv', '.ts', '.mkv', '.avi', '.webm'];
    for (const ext of videoExts) {
      if (lowerUrl.includes(ext)) return true;
    }
    
    // 检查视频路径模式
    const videoPatterns = ['/hls/', '/video/', '/stream/', '/media/', '/tos/', 'playlist.m3u8'];
    for (const pattern of videoPatterns) {
      if (lowerUrl.includes(pattern)) return true;
    }
    
    // 字节跳动系CDN（今日头条、抖音等）- 只要有/tos/就认为是视频
    const bytedanceCdns = [
      'toutiao50.com', 'toutiao.com', 'toutiaocdn.com', 
      'snssdk.com', 'amemv.com', 'bytecdn.cn', 'bytedance.com',
      'xiguavod.com', 'bdxiguavod.com'
    ];
    for (const cdn of bytedanceCdns) {
      if (lowerUrl.includes(cdn)) {
        // 字节跳动CDN只要包含/tos/或/video/就是视频
        if (lowerUrl.includes('/tos/') || lowerUrl.includes('/video/')) {
          console.log('AnimeHUBX: 通过字节跳动CDN识别视频:', cdn);
          return true;
        }
      }
    }
    
    // 检查视频参数
    const videoParams = ['mime_type=video', 'video_mp4', 'video_m3u8'];
    for (const param of videoParams) {
      if (lowerUrl.includes(param)) return true;
    }
    
    return false;
  }
  
  // 通知Flutter端发现视频链接
  function notifyVideoFound(url) {
    console.log('AnimeHUBX: 发现视频链接:', url);
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('onVideoFound', url);
    }
  }
  
  // 监听XMLHttpRequest
  const originalXHROpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (isVideoUrl(url)) {
      notifyVideoFound(url);
    }
    return originalXHROpen.apply(this, arguments);
  };
  
  // 监听fetch请求
  const originalFetch = window.fetch;
  window.fetch = function(...args) {
    const url = args[0];
    if (typeof url === 'string' && isVideoUrl(url)) {
      notifyVideoFound(url);
    }
    return originalFetch.apply(this, args);
  };
  
  // 监听video元素
  function checkVideoElements() {
    document.querySelectorAll('video').forEach(video => {
      if (video.src && isVideoUrl(video.src)) {
        notifyVideoFound(video.src);
      }
    });
    
    document.querySelectorAll('source').forEach(source => {
      if (source.src && isVideoUrl(source.src)) {
        notifyVideoFound(source.src);
      }
    });
  }
  
  // 监听DOM变化
  const domObserver = new MutationObserver(mutations => {
    mutations.forEach(mutation => {
      mutation.addedNodes.forEach(node => {
        if (node.nodeType === 1) {
          if (node.tagName === 'VIDEO' && node.src && isVideoUrl(node.src)) {
            notifyVideoFound(node.src);
          }
          if (node.querySelectorAll) {
            node.querySelectorAll('video').forEach(video => {
              if (video.src && isVideoUrl(video.src)) {
                notifyVideoFound(video.src);
              }
            });
          }
        }
      });
    });
  });
  
  domObserver.observe(document.body, { childList: true, subtree: true });
  
  // 立即检查现有元素
  checkVideoElements();
  
  console.log('AnimeHUBX: 视频监听脚本注入完成');
})();
