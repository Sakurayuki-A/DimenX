import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/source_rule.dart';

/// 视频提取结果
class VideoExtractResult {
  final bool success;
  final List<String> videoUrls;
  final String? error;
  final List<String> logs;

  VideoExtractResult({
    required this.success,
    this.videoUrls = const [],
    this.error,
    this.logs = const [],
  });
}

/// 基于WebView JS注入的视频提取器
class VideoExtractor {
  static final VideoExtractor _instance = VideoExtractor._internal();
  factory VideoExtractor() => _instance;
  VideoExtractor._internal();

  HeadlessInAppWebView? _webView;
  bool _isExtracting = false;
  Timer? _timeoutTimer;
  Completer<VideoExtractResult>? _completer;
  
  final List<String> _capturedUrls = [];
  final List<String> _logs = [];

  /// 提取视频链接 - 使用真实WebView
  Future<VideoExtractResult> extractVideoUrl(String episodeUrl, SourceRule rule) async {
    if (_isExtracting) {
      return VideoExtractResult(
        success: false,
        error: '正在进行其他提取任务',
        logs: ['并发提取被阻止'],
      );
    }

    _isExtracting = true;
    _logs.clear();
    _capturedUrls.clear();
    _completer = Completer<VideoExtractResult>();

    try {
      _log('开始使用真实WebView提取视频链接: $episodeUrl');
      
      // 不再使用简单的URL参数提取，强制使用WebView
      _log('强制使用WebView进行真实页面加载和解析');
      
      await _cleanup();
      await _createWebView(episodeUrl, rule);

      // 设置45秒超时，给WebView更多时间加载
      _timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!_completer!.isCompleted) {
          _completer!.complete(VideoExtractResult(
            success: false,
            error: 'WebView视频链接提取超时',
            logs: List.from(_logs),
          ));
        }
      });

      final result = await _completer!.future;
      return result;

    } catch (e) {
      _log('WebView提取过程异常: $e');
      return VideoExtractResult(
        success: false,
        error: 'WebView提取失败: $e',
        logs: List.from(_logs),
      );
    } finally {
      _isExtracting = false;
      await _cleanup();
    }
  }

  /// 创建真实WebView实例
  Future<void> _createWebView(String episodeUrl, SourceRule rule) async {
    _log('创建真实WebView实例，模拟完整浏览器环境');
    
    _webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri(episodeUrl),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Upgrade-Insecure-Requests': '1',
        },
      ),
      initialSettings: InAppWebViewSettings(
        // 基础设置 - 模拟真实浏览器
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        
        // 真实用户浏览器User-Agent（移除WebDriver痕迹）
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        
        // 网络和缓存设置 - 模拟真实用户行为
        cacheEnabled: true,
        clearCache: false, // 保持缓存历史
        
        // 媒体和内容设置 - 真实浏览器行为
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        allowsPictureInPictureMediaPlayback: true,
        
        // 安全和导航设置
        allowsBackForwardNavigationGestures: true,
        allowsLinkPreview: true,
        
        // 消除WebDriver特征的关键设置
        applicationNameForUserAgent: '', // 清空应用名称
        
        // 混合内容设置
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        
        // JavaScript设置 - 真实浏览器权限
        javaScriptCanOpenWindowsAutomatically: true,
        
        // 禁用可能暴露自动化特征的功能
        supportZoom: true,
        displayZoomControls: false,
        builtInZoomControls: true,
        
        // 网络超时设置
        resourceCustomSchemes: [],
        
        // 其他真实浏览器特征
        useOnDownloadStart: false,
        useShouldOverrideUrlLoading: false,
        
        // 隐私和安全设置
        incognito: false, // 不使用隐身模式
        hardwareAcceleration: true, // 启用硬件加速
        
        // 地理位置和权限
        geolocationEnabled: false,
        
        // 视口和显示设置
        supportMultipleWindows: false,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        
        // 文本和字体设置
        textZoom: 100,
        
        // 网络和连接设置
        blockNetworkImage: false,
        blockNetworkLoads: false,
        
        // 滚动和交互
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: true,
        
        // 表单和输入
        saveFormData: true,
        
        // 页面加载设置
        minimumLogicalFontSize: 8,
        minimumFontSize: 8,
        
        // 安全策略
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
      ),
      onWebViewCreated: (controller) {
        _log('WebView已创建');
        
        // 注册视频链接回调
        controller.addJavaScriptHandler(
          handlerName: 'onVideoFound',
          callback: (args) {
            if (args.isNotEmpty) {
              final url = args[0].toString();
              _onVideoFound(url);
            }
          },
        );
      },
      onLoadStart: (controller, url) async {
        _log('开始加载页面: ${url.toString()}');
      },
      
      onProgressChanged: (controller, progress) {
        _log('页面加载进度: $progress%');
      },
      
      onLoadStop: (controller, url) async {
        _log('页面加载完成: ${url.toString()}');
        
        // 等待页面完全渲染
        await Future.delayed(const Duration(seconds: 1));
        
        // 模拟真实用户行为：滚动页面
        await _simulateUserBehavior(controller);
        
        // 注入完整的反调试系统
        await _injectComprehensiveAntiDebugSystem(controller);
        
        // 然后注入视频监听脚本
        await _injectVideoMonitor(controller);
        
        // 等待JavaScript执行
        await Future.delayed(const Duration(seconds: 2));
        
        // 尝试页面解析
        await _parsePageContent(controller);
        
        // 如果还没找到视频，尝试更多交互
        if (_capturedUrls.isEmpty) {
          _log('首次解析未找到视频，尝试用户交互');
          await _triggerVideoPlay(controller);
          
          // 等待更长时间让页面响应
          await Future.delayed(const Duration(seconds: 5));
          
          // 再次尝试解析
          await _parsePageContent(controller);
        }
      },
      
      onConsoleMessage: (controller, consoleMessage) {
        _log('WebView控制台: ${consoleMessage.message}');
      },
      shouldInterceptRequest: (controller, request) async {
        final url = request.url.toString();
        
        // 检测并拦截反调试脚本
        if (_shouldBlockScript(url)) {
          _log('拦截反调试脚本: $url');
          // 返回空响应来阻止脚本加载
          return WebResourceResponse(
            contentType: 'application/javascript',
            data: Uint8List.fromList('// Script blocked by AnimeHUBX'.codeUnits),
          );
        }
        
        // 检测视频链接
        if (_isVideoUrl(url)) {
          _onVideoFound(url);
        }
        
        return null;
      },
      onReceivedError: (controller, request, error) {
        _log('页面加载错误: ${error.description}');
      },
    );

    await _webView!.run();
    _log('WebView运行成功');
  }

  /// 注入完整的反调试系统
  Future<void> _injectComprehensiveAntiDebugSystem(InAppWebViewController controller) async {
    _log('注入完整的反调试系统');
    
    const script = '''
      (function() {
        console.log('AnimeHUBX: 启动完整反调试系统');
        
        // ===== 第一层：基础反调试保护 =====
        
        // 1. 全面的debugger语句拦截
        const originalFunction = Function;
        window.Function = function(...args) {
          const code = args[args.length - 1];
          if (typeof code === 'string') {
            // 检测各种debugger变体
            const debuggerPatterns = [
              /debugger/gi, /\\x64\\x65\\x62\\x75\\x67\\x67\\x65\\x72/gi,
              /\\u0064\\u0065\\u0062\\u0075\\u0067\\u0067\\u0065\\u0072/gi
            ];
            for (let pattern of debuggerPatterns) {
              if (pattern.test(code)) {
                console.log('AnimeHUBX: 拦截Function中的debugger');
                return function() { return false; };
              }
            }
          }
          return originalFunction.apply(this, args);
        };
        
        // 2. 高级console保护
        const originalConsole = window.console;
        const consoleProxy = new Proxy(originalConsole, {
          get: function(target, prop) {
            const blockedMethods = ['clear', 'table', 'trace', 'profile', 'profileEnd'];
            if (blockedMethods.includes(prop)) {
              return function() {
                console.log('AnimeHUBX: 拦截console.' + prop);
              };
            }
            return target[prop];
          },
          set: function(target, prop, value) {
            console.log('AnimeHUBX: 阻止console.' + prop + '被重写');
            return true;
          }
        });
        window.console = consoleProxy;
        
        // 3. 窗口和屏幕属性伪造
        const fakeProperties = {
          'outerHeight': () => window.innerHeight,
          'outerWidth': () => window.innerWidth,
          'screenX': () => 0,
          'screenY': () => 0,
          'screenLeft': () => 0,
          'screenTop': () => 0
        };
        
        for (let [prop, getter] of Object.entries(fakeProperties)) {
          try {
            Object.defineProperty(window, prop, {
              get: getter,
              configurable: false,
              enumerable: true
            });
          } catch(e) {}
        }
        
        // ===== 第二层：定时器和异步保护 =====
        
        // 4. 增强的定时器拦截
        const wrapTimerFunction = (originalFunc, name) => {
          return function(callback, delay, ...args) {
            if (typeof callback === 'string') {
              if (/debugger|eval\\s*\\(/gi.test(callback)) {
                console.log('AnimeHUBX: 拦截' + name + '中的危险代码');
                return originalFunc(() => {}, delay, ...args);
              }
            } else if (typeof callback === 'function') {
              const funcStr = callback.toString();
              if (/debugger|console\\.clear|performance\\.now/gi.test(funcStr)) {
                console.log('AnimeHUBX: 拦截' + name + '回调中的检测代码');
                return originalFunc(() => {}, delay, ...args);
              }
            }
            return originalFunc(callback, delay, ...args);
          };
        };
        
        window.setTimeout = wrapTimerFunction(window.setTimeout, 'setTimeout');
        window.setInterval = wrapTimerFunction(window.setInterval, 'setInterval');
        
        // ===== 第三层：环境检测防护 =====
        
        // 5. 完整的Navigator对象WebDriver特征消除
        const navigatorProxy = new Proxy(navigator, {
          get: function(target, prop) {
            // 完全消除WebDriver特征的伪造值
            const fakeValues = {
              // 核心WebDriver特征消除
              'webdriver': undefined, // 完全移除webdriver属性
              'webDriver': undefined,
              '__webdriver_script_fn': undefined,
              '__selenium_unwrapped': undefined,
              '__webdriver_unwrapped': undefined,
              '__driver_evaluate': undefined,
              '__webdriver_evaluate': undefined,
              '__selenium_evaluate': undefined,
              '__fxdriver_evaluate': undefined,
              '__driver_unwrapped': undefined,
              '__fxdriver_unwrapped': undefined,
              '__webdriver_script_func': undefined,
              
              // 真实浏览器属性
              'plugins': target.plugins,
              'mimeTypes': target.mimeTypes,
              'languages': ['zh-CN', 'zh', 'en-US', 'en'],
              'language': 'zh-CN',
              'platform': 'Win32',
              'cookieEnabled': true,
              'onLine': true,
              'doNotTrack': null,
              'maxTouchPoints': 0,
              'hardwareConcurrency': 8,
              'deviceMemory': 8,
              
              // 清理User-Agent中的自动化痕迹
              'userAgent': target.userAgent
                .replace(/HeadlessChrome/gi, 'Chrome')
                .replace(/PhantomJS/gi, 'Chrome')
                .replace(/Selenium/gi, '')
                .replace(/WebDriver/gi, '')
                .replace(/Automation/gi, '')
                .replace(/Bot/gi, '')
                .replace(/Crawler/gi, '')
                .replace(/Spider/gi, '')
                .replace(/\\s+/g, ' ')
                .trim(),
              
              // 真实浏览器标识
              'appName': 'Netscape',
              'appCodeName': 'Mozilla',
              'appVersion': target.appVersion.replace(/HeadlessChrome|PhantomJS|Selenium|WebDriver/gi, 'Chrome'),
              'product': 'Gecko',
              'productSub': '20030107',
              'vendor': 'Google Inc.',
              'vendorSub': '',
              
              // 权限API伪造
              'permissions': target.permissions,
              'serviceWorker': target.serviceWorker,
              'storage': target.storage,
              'geolocation': target.geolocation,
              
              // 连接信息
              'connection': target.connection || {
                effectiveType: '4g',
                downlink: 10,
                rtt: 100,
                saveData: false
              }
            };
            
            if (prop in fakeValues) {
              return fakeValues[prop];
            }
            return target[prop];
          },
          
          has: function(target, prop) {
            // 隐藏WebDriver相关属性的存在
            const hiddenProps = [
              'webdriver', 'webDriver', '__webdriver_script_fn',
              '__selenium_unwrapped', '__webdriver_unwrapped',
              '__driver_evaluate', '__webdriver_evaluate',
              '__selenium_evaluate', '__fxdriver_evaluate',
              '__driver_unwrapped', '__fxdriver_unwrapped',
              '__webdriver_script_func'
            ];
            
            if (hiddenProps.includes(prop)) {
              return false;
            }
            return prop in target;
          },
          
          ownKeys: function(target) {
            // 从属性列表中移除WebDriver相关属性
            return Object.getOwnPropertyNames(target).filter(prop => {
              const hiddenProps = [
                'webdriver', 'webDriver', '__webdriver_script_fn',
                '__selenium_unwrapped', '__webdriver_unwrapped'
              ];
              return !hiddenProps.includes(prop);
            });
          }
        });
        
        try {
          Object.defineProperty(window, 'navigator', {
            value: navigatorProxy,
            configurable: false
          });
        } catch(e) {}
        
        // 6. Performance API保护
        const originalPerformanceNow = performance.now;
        let performanceOffset = 0;
        performance.now = function() {
          const realTime = originalPerformanceNow.call(performance);
          return realTime + performanceOffset;
        };
        
        // 7. Date对象高级保护
        const originalDate = Date;
        const originalDateNow = Date.now;
        let timeOffset = 0;
        
        Date.now = function() {
          return originalDateNow() + timeOffset;
        };
        
        window.Date = function(...args) {
          if (args.length === 0) {
            return new originalDate(originalDateNow() + timeOffset);
          }
          return new originalDate(...args);
        };
        
        Object.setPrototypeOf(window.Date, originalDate);
        Object.defineProperties(window.Date, Object.getOwnPropertyDescriptors(originalDate));
        
        // ===== 第四层：事件和交互保护 =====
        
        // 8. 全面的键盘事件拦截
        const keyboardHandler = function(e) {
          const blockedKeys = [
            'F12', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11'
          ];
          
          const blockedCombinations = [
            {ctrl: true, shift: true, key: 'I'}, // Ctrl+Shift+I
            {ctrl: true, shift: true, key: 'J'}, // Ctrl+Shift+J
            {ctrl: true, shift: true, key: 'C'}, // Ctrl+Shift+C
            {ctrl: true, key: 'U'}, // Ctrl+U
            {ctrl: true, key: 'S'}, // Ctrl+S
            {key: 'F12'} // F12
          ];
          
          for (let combo of blockedCombinations) {
            let matches = true;
            for (let [modifier, value] of Object.entries(combo)) {
              if (modifier === 'key') {
                if (e.key !== value && e.code !== value) matches = false;
              } else {
                if (e[modifier] !== value) matches = false;
              }
            }
            if (matches) {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              console.log('AnimeHUBX: 拦截键盘快捷键');
              return false;
            }
          }
        };
        
        document.addEventListener('keydown', keyboardHandler, true);
        document.addEventListener('keyup', keyboardHandler, true);
        document.addEventListener('keypress', keyboardHandler, true);
        
        // 9. 右键菜单完全禁用
        const contextMenuHandler = function(e) {
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          return false;
        };
        
        document.addEventListener('contextmenu', contextMenuHandler, true);
        document.addEventListener('selectstart', contextMenuHandler, true);
        document.addEventListener('dragstart', contextMenuHandler, true);
        
        // ===== 第五层：高级检测防护 =====
        
        // 10. 堆栈跟踪保护
        const originalError = Error;
        window.Error = function(...args) {
          const err = new originalError(...args);
          Object.defineProperty(err, 'stack', {
            get: function() {
              return 'Error: Protected by AnimeHUBX\\n    at <anonymous>';
            }
          });
          return err;
        };
        
        // 11. eval和Function.constructor保护
        const originalEval = window.eval;
        window.eval = function(code) {
          if (typeof code === 'string' && /debugger|console\\.clear/gi.test(code)) {
            console.log('AnimeHUBX: 拦截eval中的检测代码');
            return undefined;
          }
          return originalEval(code);
        };
        
        // 12. 网络请求监控防护
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          const url = args[0];
          if (typeof url === 'string' && /devtools|debug|anti/gi.test(url)) {
            console.log('AnimeHUBX: 拦截可疑网络请求');
            return Promise.resolve(new Response('{}', {status: 200}));
          }
          return originalFetch.apply(this, args);
        };
        
        // 13. WebSocket保护
        const originalWebSocket = window.WebSocket;
        window.WebSocket = function(url, protocols) {
          if (typeof url === 'string' && /devtools|debug|monitor/gi.test(url)) {
            console.log('AnimeHUBX: 拦截可疑WebSocket连接');
            throw new Error('Connection blocked by AnimeHUBX');
          }
          return new originalWebSocket(url, protocols);
        };
        
        // ===== 第六层：DOM和样式保护 =====
        
        // 14. MutationObserver保护
        const originalMutationObserver = window.MutationObserver;
        window.MutationObserver = function(callback) {
          const wrappedCallback = function(mutations, observer) {
            // 过滤掉可能的检测相关变化
            const filteredMutations = mutations.filter(mutation => {
              return !mutation.target.classList?.contains('devtools-detector');
            });
            if (filteredMutations.length > 0) {
              callback(filteredMutations, observer);
            }
          };
          return new originalMutationObserver(wrappedCallback);
        };
        
        // 15. 样式计算保护
        const originalGetComputedStyle = window.getComputedStyle;
        window.getComputedStyle = function(element, pseudoElement) {
          const styles = originalGetComputedStyle(element, pseudoElement);
          // 防止通过样式检测开发者工具
          return new Proxy(styles, {
            get: function(target, prop) {
              if (prop === 'width' || prop === 'height') {
                return target[prop];
              }
              return target[prop];
            }
          });
        };
        
        // ===== 第七层：WebDriver特征完全消除 =====
        
        // 16. 全局WebDriver属性清理
        const webdriverProps = [
          'webdriver', '__webdriver_script_fn', '__selenium_unwrapped',
          '__webdriver_unwrapped', '__driver_evaluate', '__webdriver_evaluate',
          '__selenium_evaluate', '__fxdriver_evaluate', '__driver_unwrapped',
          '__fxdriver_unwrapped', '__webdriver_script_func', '__webdriver_script_function',
          '_phantom', '__phantom', 'callPhantom', '_selenium', 'calledSelenium',
          '\$chrome_asyncScriptInfo', '__\$webdriverAsyncExecutor', 'webdriver-evaluate',
          'selenium-evaluate', 'webdriverCommand', 'webdriver-evaluate-response'
        ];
        
        // 从window对象中移除WebDriver属性
        webdriverProps.forEach(prop => {
          try {
            if (prop in window) {
              delete window[prop];
            }
            Object.defineProperty(window, prop, {
              get: function() { return undefined; },
              set: function() { return true; },
              configurable: true
            });
          } catch(e) {}
        });
        
        // 17. Chrome Runtime API伪造
        if (window.chrome) {
          window.chrome = new Proxy(window.chrome, {
            get: function(target, prop) {
              if (prop === 'runtime') {
                return {
                  onConnect: undefined,
                  onMessage: undefined,
                  connect: function() { return null; },
                  sendMessage: function() { return null; }
                };
              }
              return target[prop];
            }
          });
        } else {
          // 创建伪造的chrome对象
          Object.defineProperty(window, 'chrome', {
            value: {
              app: { isInstalled: false },
              webstore: {
                onInstallStageChanged: {},
                onDownloadProgress: {}
              },
              runtime: {
                onConnect: undefined,
                onMessage: undefined,
                connect: function() { return null; },
                sendMessage: function() { return null; }
              }
            },
            configurable: true
          });
        }
        
        // 18. 自动化检测属性伪造
        const automationProps = {
          'cdc_adoQpoasnfa76pfcZLmcfl_Array': undefined,
          'cdc_adoQpoasnfa76pfcZLmcfl_Promise': undefined,
          'cdc_adoQpoasnfa76pfcZLmcfl_Symbol': undefined,
          '\$cdc_asdjflasutopfhvcZLmcfl_': undefined,
          '\$chrome_asyncScriptInfo': undefined,
          '__webdriver_script_fn': undefined
        };
        
        Object.keys(automationProps).forEach(prop => {
          try {
            if (prop in window) {
              delete window[prop];
            }
            Object.defineProperty(window, prop, {
              get: function() { return undefined; },
              configurable: true
            });
          } catch(e) {}
        });
        
        // 19. Document属性清理
        const documentProps = ['webdriver', '__webdriver_unwrapped', '__driver_evaluate'];
        documentProps.forEach(prop => {
          try {
            if (prop in document) {
              delete document[prop];
            }
          } catch(e) {}
        });
        
        // 20. 权限查询伪造
        if (navigator.permissions && navigator.permissions.query) {
          const originalQuery = navigator.permissions.query;
          navigator.permissions.query = function(parameters) {
            if (parameters.name === 'notifications') {
              return Promise.resolve({ state: 'default' });
            }
            return originalQuery(parameters);
          };
        }
        
        // 21. WebGL指纹伪造
        const getParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(parameter) {
          if (parameter === 37445) { // UNMASKED_VENDOR_WEBGL
            return 'Intel Inc.';
          }
          if (parameter === 37446) { // UNMASKED_RENDERER_WEBGL
            return 'Intel(R) HD Graphics 620';
          }
          return getParameter.call(this, parameter);
        };
        
        // 22. Console对象检测绕过
        const originalConsole = window.console;
        const fakeConsole = {
          // 基础日志方法 - 静默处理
          log: function() { /* 静默 */ },
          debug: function() { /* 静默 */ },
          info: function() { /* 静默 */ },
          warn: function() { /* 静默 */ },
          error: function() { /* 静默 */ },
          
          // 调试方法 - 伪造正常行为
          clear: function() { 
            // 伪造清屏，实际不执行
            return undefined;
          },
          
          // 时间测量方法
          time: function(label) {
            this._timers = this._timers || {};
            this._timers[label] = Date.now();
          },
          timeEnd: function(label) {
            if (this._timers && this._timers[label]) {
              const duration = Date.now() - this._timers[label];
              delete this._timers[label];
              return duration;
            }
          },
          
          // 分组方法
          group: function() { /* 静默 */ },
          groupCollapsed: function() { /* 静默 */ },
          groupEnd: function() { /* 静默 */ },
          
          // 表格和计数
          table: function() { /* 静默 */ },
          count: function() { /* 静默 */ },
          countReset: function() { /* 静默 */ },
          
          // 断言和跟踪
          assert: function() { /* 静默 */ },
          trace: function() { /* 静默 */ },
          
          // 性能分析
          profile: function() { /* 静默 */ },
          profileEnd: function() { /* 静默 */ },
          
          // 目录显示
          dir: function() { /* 静默 */ },
          dirxml: function() { /* 静默 */ }
        };
        
        // 伪造toString方法，使其看起来像原生代码
        Object.keys(fakeConsole).forEach(key => {
          if (typeof fakeConsole[key] === 'function') {
            fakeConsole[key].toString = function() {
              return 'function ' + key + '() { [native code] }';
            };
          }
        });
        
        // 使用Proxy进一步增强console伪造
        const consoleProxy = new Proxy(fakeConsole, {
          get: function(target, prop) {
            // 如果属性存在于伪造对象中，返回伪造值
            if (prop in target) {
              return target[prop];
            }
            
            // 对于未定义的属性，返回空函数
            if (typeof prop === 'string') {
              const fakeMethod = function() { /* 静默 */ };
              fakeMethod.toString = function() {
                return 'function ' + prop + '() { [native code] }';
              };
              return fakeMethod;
            }
            
            return undefined;
          },
          
          has: function(target, prop) {
            // 伪造console对象拥有所有标准方法
            const standardMethods = [
              'log', 'debug', 'info', 'warn', 'error', 'clear',
              'time', 'timeEnd', 'group', 'groupCollapsed', 'groupEnd',
              'table', 'count', 'countReset', 'assert', 'trace',
              'profile', 'profileEnd', 'dir', 'dirxml'
            ];
            return standardMethods.includes(prop) || prop in target;
          },
          
          ownKeys: function(target) {
            // 返回标准console方法列表
            return [
              'log', 'debug', 'info', 'warn', 'error', 'clear',
              'time', 'timeEnd', 'group', 'groupCollapsed', 'groupEnd',
              'table', 'count', 'countReset', 'assert', 'trace',
              'profile', 'profileEnd', 'dir', 'dirxml'
            ];
          }
        });
        
        // 替换全局console对象
        Object.defineProperty(window, 'console', {
          get: function() {
            return consoleProxy;
          },
          set: function(value) {
            // 阻止console对象被重新设置
            return consoleProxy;
          },
          configurable: false,
          enumerable: true
        });
        
        // 确保console.clear看起来像原生方法
        Object.defineProperty(consoleProxy.clear, 'toString', {
          value: function() {
            return 'function clear() { [native code] }';
          },
          writable: false,
          configurable: false
        });
        
        // ===== 系统启动完成 =====
        
        console.log('AnimeHUBX: 完整反调试系统启动完成');
        console.log('AnimeHUBX: 已启用22层防护机制');
        console.log('AnimeHUBX: WebDriver特征完全消除');
        console.log('AnimeHUBX: Console对象检测已绕过');
        
        // 定期检查和维护
        setInterval(() => {
          // 重新检查关键保护是否被绕过
          try {
            // 检查console对象是否被替换
            if (window.console !== consoleProxy) {
              console.log('AnimeHUBX: 检测到console保护被绕过，重新加固');
              // 重新定义console对象
              Object.defineProperty(window, 'console', {
                get: function() { return consoleProxy; },
                set: function(value) { return consoleProxy; },
                configurable: false,
                enumerable: true
              });
            }
            
            // 检查webdriver属性是否重新出现
            if (navigator.webdriver !== undefined) {
              Object.defineProperty(navigator, 'webdriver', {
                get: function() { return undefined; },
                configurable: true
              });
            }
          } catch(e) {
            // 静默处理检查错误
          }
        }, 5000);
        
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
      _log('完整反调试系统注入成功 - 已启用22层防护机制');
    } catch (e) {
      _log('完整反调试系统注入失败: $e');
    }
  }

  /// 注入视频监听脚本
  Future<void> _injectVideoMonitor(InAppWebViewController controller) async {
    const script = '''
      (function() {
        console.log('注入视频监听脚本');
        
        // 视频URL检测函数
        function isVideoUrl(url) {
          if (!url || typeof url !== 'string') return false;
          
          const lowerUrl = url.toLowerCase();
          
          // 排除非视频文件
          const excludeExts = ['.jpg', '.jpeg', '.png', '.gif', '.css', '.js', '.html', '.txt'];
          for (const ext of excludeExts) {
            if (lowerUrl.includes(ext)) return false;
          }
          
          // 检查视频文件扩展名
          const videoExts = ['.m3u8', '.mp4', '.flv', '.ts', '.mkv', '.avi', '.webm'];
          for (const ext of videoExts) {
            if (lowerUrl.includes(ext)) return true;
          }
          
          // 检查视频路径模式
          const videoPatterns = ['/hls/', '/video/', '/stream/', '/media/', 'playlist.m3u8', 'index.m3u8'];
          for (const pattern of videoPatterns) {
            if (lowerUrl.includes(pattern)) return true;
          }
          
          // 检查blob和data链接
          if (url.startsWith('blob:') || url.startsWith('data:video/')) return true;
          
          return false;
        }
        
        // 通知Flutter端发现视频链接
        function notifyVideoFound(url) {
          console.log('发现视频链接:', url);
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('onVideoFound', url);
          }
        }
        
        // 监听XMLHttpRequest
        const originalXHROpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
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
            
            // 监听src属性变化
            const observer = new MutationObserver(mutations => {
              mutations.forEach(mutation => {
                if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
                  if (video.src && isVideoUrl(video.src)) {
                    notifyVideoFound(video.src);
                  }
                }
              });
            });
            observer.observe(video, { attributes: true, attributeFilter: ['src'] });
          });
          
          // 检查source元素
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
                if (node.tagName === 'SOURCE' && node.src && isVideoUrl(node.src)) {
                  notifyVideoFound(node.src);
                }
                
                // 检查新添加节点内的video元素
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
        
        console.log('视频监听脚本注入完成');
      })();
    ''';

    await controller.evaluateJavascript(source: script);
    _log('视频监听脚本已注入');
  }

  /// 模拟真实用户行为
  Future<void> _simulateUserBehavior(InAppWebViewController controller) async {
    _log('模拟真实用户行为');
    
    const script = '''
      (function() {
        console.log('开始模拟用户行为');
        
        // 模拟鼠标移动
        const mouseMoveEvent = new MouseEvent('mousemove', {
          bubbles: true,
          cancelable: true,
          clientX: 100,
          clientY: 100
        });
        document.dispatchEvent(mouseMoveEvent);
        
        // 模拟页面滚动
        window.scrollTo(0, 100);
        setTimeout(() => window.scrollTo(0, 0), 500);
        
        // 模拟点击页面
        const clickEvent = new MouseEvent('click', {
          bubbles: true,
          cancelable: true
        });
        document.body.dispatchEvent(clickEvent);
        
        // 模拟键盘事件
        const keyEvent = new KeyboardEvent('keydown', {
          bubbles: true,
          cancelable: true,
          key: 'Space'
        });
        document.dispatchEvent(keyEvent);
        
        // 触发页面焦点
        if (document.body) {
          document.body.focus();
        }
        
        console.log('用户行为模拟完成');
        return true;
      })();
    ''';

    try {
      await controller.evaluateJavascript(source: script);
      _log('用户行为模拟完成');
    } catch (e) {
      _log('用户行为模拟失败: $e');
    }
  }

  /// 触发视频播放
  Future<void> _triggerVideoPlay(InAppWebViewController controller) async {
    const script = '''
      (function() {
        console.log('尝试触发视频播放');
        
        // 查找并点击播放按钮
        const playSelectors = [
          '.play-btn', '.play-button', '.btn-play',
          '[class*="play"]', '[id*="play"]',
          'button[title*="播放"]', 'button[title*="Play"]',
          '.video-play', '.player-play'
        ];
        
        let clicked = false;
        for (const selector of playSelectors) {
          const buttons = document.querySelectorAll(selector);
          for (const button of buttons) {
            if (button.offsetParent !== null) {
              button.click();
              console.log('点击播放按钮:', selector);
              clicked = true;
              break;
            }
          }
          if (clicked) break;
        }
        
        // 尝试直接播放video元素
        document.querySelectorAll('video').forEach(video => {
          video.play().catch(e => console.log('视频播放失败:', e.message));
        });
        
        // 模拟用户交互
        document.body.click();
        
        return clicked;
      })();
    ''';

    final result = await controller.evaluateJavascript(source: script);
    _log('播放触发结果: $result');
  }

  /// 解析页面内容
  Future<void> _parsePageContent(InAppWebViewController controller) async {
    _log('开始解析页面内容');
    
    const script = '''
      (function() {
        const results = [];
        
        // 获取页面HTML
        const html = document.documentElement.outerHTML;
        console.log('页面HTML长度:', html.length);
        
        // 检查是否是播放器页面（包含url参数）
        const currentUrl = window.location.href;
        console.log('当前页面URL:', currentUrl);
        
        if (currentUrl.includes('player/?url=')) {
          // 提取URL参数中的视频链接
          const urlMatch = currentUrl.match(/[?&]url=([^&]+)/);
          if (urlMatch) {
            const videoUrl = decodeURIComponent(urlMatch[1]);
            console.log('从URL参数提取到视频链接:', videoUrl);
            results.push(videoUrl);
          }
        }
        
        // 查找页面中的视频链接
        const patterns = [
          // 直接的m3u8链接
          /https?:\\/\\/[^"\\s]+\\.m3u8[^"\\s]*/gi,
          // 带引号的m3u8链接
          /"(https?:\\/\\/[^"]+\\.m3u8[^"]*)"/gi,
          /'(https?:\\/\\/[^']+\\.m3u8[^']*)'/gi,
          // JavaScript变量中的链接
          /(?:src|url|video)\\s*[:=]\\s*["'](https?:\\/\\/[^"']+\\.m3u8[^"']*)/gi,
          // 其他视频格式
          /https?:\\/\\/[^"\\s]+\\.(?:mp4|flv|ts)[^"\\s]*/gi,
          /"(https?:\\/\\/[^"]+\\.(?:mp4|flv|ts)[^"]*)"/gi
        ];
        
        patterns.forEach(pattern => {
          let match;
          while ((match = pattern.exec(html)) !== null) {
            const url = match[1] || match[0];
            if (url && !url.includes('vodplay/') && !url.includes('voddetail/')) {
              const cleanUrl = url.replace(/['"\\s]/g, '');
              console.log('正则匹配到视频链接:', cleanUrl);
              results.push(cleanUrl);
            }
          }
        });
        
        // 查找iframe中的视频源
        document.querySelectorAll('iframe').forEach(iframe => {
          if (iframe.src && iframe.src.includes('m3u8')) {
            console.log('iframe中发现视频链接:', iframe.src);
            results.push(iframe.src);
          }
        });
        
        // 查找video标签的src
        document.querySelectorAll('video').forEach(video => {
          if (video.src) {
            console.log('video标签src:', video.src);
            results.push(video.src);
          }
          // 检查source子元素
          video.querySelectorAll('source').forEach(source => {
            if (source.src) {
              console.log('source标签src:', source.src);
              results.push(source.src);
            }
          });
        });
        
        const uniqueResults = [...new Set(results)];
        console.log('总共找到', uniqueResults.length, '个视频链接');
        return uniqueResults;
      })();
    ''';

    try {
      final result = await controller.evaluateJavascript(source: script);
      if (result is List) {
        for (final url in result) {
          if (url is String && _isVideoUrl(url)) {
            _onVideoFound(url);
          }
        }
      }
    } catch (e) {
      _log('页面解析失败: $e');
    }
  }

  /// 处理发现的视频链接 - 真实WebView模式
  void _onVideoFound(String url) {
    if (url.isEmpty || _capturedUrls.contains(url)) return;
    
    _log('WebView发现链接: $url');
    
    // 在真实WebView模式下，我们需要更仔细地处理发现的链接
    if (url.contains('player/?url=')) {
      _log('发现播放器页面URL，通过WebView进一步解析');
      
      // 不直接提取URL参数，而是让WebView加载这个页面
      // 这样可以处理更复杂的JavaScript加载逻辑
      final urlMatch = RegExp(r'[?&]url=([^&]+)').firstMatch(url);
      if (urlMatch != null) {
        final potentialVideoUrl = Uri.decodeComponent(urlMatch.group(1)!);
        _log('从播放器URL发现潜在视频链接: $potentialVideoUrl');
        
        if (_isVideoUrl(potentialVideoUrl)) {
          _capturedUrls.add(potentialVideoUrl);
          _log('WebView捕获视频链接: $potentialVideoUrl');
          
          // 继续让WebView运行，可能还有其他链接
          // 不立即完成，让WebView有机会发现更多链接
        }
      }
    } else if (_isVideoUrl(url)) {
      // 处理直接的视频链接
      _capturedUrls.add(url);
      _log('WebView捕获直接视频链接: $url');
    }
    
    // 如果我们已经找到了视频链接，但让WebView继续运行一段时间
    // 以防有更好的链接或多个质量选项
    if (_capturedUrls.isNotEmpty && _completer != null && !_completer!.isCompleted) {
      // 延迟完成，给WebView更多时间
      Timer(const Duration(seconds: 3), () {
        if (_completer != null && !_completer!.isCompleted) {
          _log('WebView提取完成，找到 ${_capturedUrls.length} 个视频链接');
          _completer!.complete(VideoExtractResult(
            success: true,
            videoUrls: List.from(_capturedUrls),
            logs: List.from(_logs),
          ));
        }
      });
    }
  }

  /// 检查是否应该拦截脚本 - 增强版
  bool _shouldBlockScript(String url) {
    if (url.isEmpty) return false;
    
    final lowerUrl = url.toLowerCase();
    
    // 扩展的反调试脚本列表
    final blockedScripts = [
      // 开发者工具检测
      'devtools-detector.js', 'devtools-detect.js', 'anti-devtools.js',
      'debugger-detector.js', 'console-ban.js', 'disable-devtools.js',
      'anti-debug.js', 'devtools-blocker.js', 'f12-disable.js',
      'inspect-disable.js', 'right-click-disable.js', 'context-menu-disable.js',
      'developer-tools-detector.js', 'anti-developer-tools.js',
      
      // 高级反调试脚本
      'anti-tamper.js', 'code-protection.js', 'obfuscator.js',
      'vm-detect.js', 'headless-detect.js', 'automation-detect.js',
      'bot-detector.js', 'crawler-blocker.js', 'scraper-detect.js',
      
      // 性能分析和监控
      'performance-monitor.js', 'timing-attack.js', 'execution-monitor.js',
      'stack-trace-blocker.js', 'source-map-blocker.js',
      
      // 网络和请求监控
      'xhr-monitor.js', 'fetch-monitor.js', 'network-detector.js',
      'proxy-detect.js', 'mitm-detect.js',
      
      // 环境检测
      'environment-check.js', 'browser-fingerprint.js', 'ua-check.js',
      'webdriver-detect.js', 'phantom-detect.js', 'selenium-detect.js',
      
      // 代码混淆和保护
      'code-encrypt.js', 'string-encrypt.js', 'eval-protect.js',
      'function-protect.js', 'dom-protect.js',
    ];
    
    // 检查URL是否包含被拦截的脚本名
    for (final script in blockedScripts) {
      if (lowerUrl.contains(script)) {
        return true;
      }
    }
    
    // 扩展的反调试代码特征检测
    final antiDebugPatterns = [
      // 基础调试检测
      r'debugger[;\s]', r'console\.clear', r'setinterval.*debugger',
      r'settimeout.*debugger', r'anti.*debug', r'disable.*f12',
      r'block.*devtools', r'prevent.*inspect',
      
      // 高级检测模式
      r'performance\.now', r'date\.now.*\d{3,}', r'window\.outer.*height',
      r'screen\.avail.*', r'navigator\.webdriver', r'window\.phantom',
      r'window\.selenium', r'window\.callphantom', r'__nightmare',
      
      // 代码保护模式
      r'eval\s*\(.*atob', r'function.*constructor.*debugger',
      r'setinterval.*function.*\(\).*debugger', r'while.*true.*debugger',
      
      // 环境检测
      r'headless.*chrome', r'automation.*extension', r'webdriver.*true',
      r'chrome.*runtime', r'phantom.*version',
    ];
    
    for (final pattern in antiDebugPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(lowerUrl)) {
        return true;
      }
    }
    
    // 检查可疑的CDN和第三方服务
    final suspiciousDomains = [
      'anti-debug.com', 'devtools-detect.net', 'code-protect.io',
      'bot-detector.org', 'scraper-block.com', 'automation-detect.net',
    ];
    
    for (final domain in suspiciousDomains) {
      if (lowerUrl.contains(domain)) {
        return true;
      }
    }
    
    return false;
  }

  /// 检查是否为视频URL
  bool _isVideoUrl(String url) {
    if (url.isEmpty) return false;
    
    final lowerUrl = url.toLowerCase();
    
    // 排除明显不是视频的文件
    final excludePatterns = [
      r'\.(jpg|jpeg|png|gif|webp|svg|ico|css|js|html|htm|txt|xml|json)(\?|$)',
      r'/(api|ajax|json|xml|search|login|register)/',
      r'vodplay/\d+-\d+-\d+\.html$',
      r'voddetail/\d+\.html$',
    ];
    
    for (final pattern in excludePatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(url)) {
        return false;
      }
    }
    
    // 检查视频文件扩展名
    final videoExtensions = ['.m3u8', '.mp4', '.flv', '.ts', '.mkv', '.avi', '.webm', '.mov', '.wmv'];
    for (final ext in videoExtensions) {
      if (lowerUrl.contains(ext)) return true;
    }
    
    // 检查视频路径模式
    final videoPatterns = [
      r'/hls/', r'/video/', r'/stream/', r'/media/', r'/live/',
      r'playlist\.m3u8', r'index\.m3u8', r'master\.m3u8',
      r'blob:', r'data:video/'
    ];
    
    for (final pattern in videoPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(url)) return true;
    }
    
    return false;
  }

  /// 记录日志
  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    if (kDebugMode) {
      print('VideoExtractor: $logMessage');
    }
  }

  /// 清理资源
  Future<void> _cleanup() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    
    if (_webView != null) {
      try {
        await _webView!.dispose();
      } catch (e) {
        _log('WebView清理失败: $e');
      }
      _webView = null;
    }
    
    _capturedUrls.clear();
  }

  /// 停止提取
  Future<void> stopExtraction() async {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(VideoExtractResult(
        success: false,
        error: '用户取消提取',
        logs: List.from(_logs),
      ));
    }
    await _cleanup();
  }
}
