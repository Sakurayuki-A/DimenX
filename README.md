# DimenX

一个基于 Flutter 开发的 Windows 桌面端动漫观看应用，采用模块化架构设计，提供高精度搜索和智能视频提取功能。

## ✨ 功能特性

### 🎬 核心功能
- **动漫浏览** - 精美的网格布局展示动漫列表，支持骨架屏加载
- **高精度搜索** - V2 重构架构，搜索精度提升至 90%+
  - 智能节点过滤，过滤率达 90%
  - 多策略标题提取和验证
  - 系列作品智能去重和分组
  - 支持自定义搜索规则
  - 智能缓存机制（2分钟有效期）
  - 支持静态/动态页面混合加载
- **智能视频提取** - V2 模块化架构
  - 自动检测和提取 m3u8/mp4 视频链接
  - 支持多层 iframe 递归解析
  - 反调试和 URL 监控机制
  - 智能超时和快速完成策略（100ms 响应）
  - 支持字节跳动 CDN 签名链接识别
  - 自动 URL 拼接和域名识别
- **多源播放** - 支持多个动漫播放源切换
  - 底部弹出式播放源选择
  - 自动搜索和在线状态检测
  - 多路线智能切换
  - 实时加载动画和状态提示
- **视频播放** - 基于 media_kit 的高性能播放器
  - 支持全屏播放和画中画
  - 流畅的播放控制
  - 集数快速切换（右侧滑出式选择器）
  - 路线优先选择（先选路线再选集数）
  - 自动播放控制（等待用户选择集数）
- **收藏管理** - 收藏喜爱的动漫，本地持久化存储
- **观看历史** - 自动记录观看历史，支持清除功能
- **番剧日历** - 集成 Bangumi API，查看番剧更新时间表
- **评论互动** - 查看 Bangumi 社区评论和讨论

### 🖥️ 桌面端优化
- **自定义标题栏** - 现代化的无边框窗口设计
- **响应式布局** - 适配不同屏幕尺寸
- **流畅动画** - 卡片悬停效果和页面切换动画
- **深色主题** - 护眼的深色界面设计
- **窗口管理** - 支持窗口拖拽、最小化、最大化

### 🎨 用户界面
- **侧边栏导航** - 清晰的功能分类和快速切换
- **动漫卡片** - 显示封面、评分、类型等信息
- **详情页面** - 完整的动漫信息展示，集成 Bangumi 数据
- **播放控制** - 集成播放控制和集数选择
- **骨架屏加载** - 优雅的加载状态展示

## 🛠️ 技术栈

### 核心框架
- **Flutter 3.0+** - 跨平台 UI 框架
- **Provider** - 状态管理解决方案

### 视频播放
- **media_kit** - 高性能视频播放引擎
- **media_kit_video** - 视频播放 UI 组件
- **media_kit_libs_windows_video** - Windows 平台视频库
- **video_player** - 备用视频播放器
- **chewie** - 视频播放器 UI 增强

### 网络与解析
- **http** - HTTP 请求库
- **html** - HTML 解析库
- **flutter_inappwebview** - WebView 组件，用于视频链接提取

### 数据与缓存
- **cached_network_image** - 图片缓存和加载
- **shared_preferences** - 本地数据持久化存储

### UI 组件
- **flutter_staggered_grid_view** - 瀑布流网格布局
- **window_manager** - 窗口管理
- **bitsdojo_window** - 自定义窗口装饰

### 工具库
- **url_launcher** - URL 启动器

## 📁 项目结构

```
lib/
├── main.dart                          # 应用入口
├── config/                            # 配置
│   └── image_cache_config.dart        # 图片缓存配置
├── models/                            # 数据模型
│   ├── anime.dart                     # 动漫数据模型
│   └── source_rule.dart               # 播放源规则模型
├── providers/                         # 状态管理
│   ├── anime_provider.dart            # 动漫数据提供者
│   ├── favorites_provider.dart        # 收藏管理
│   ├── history_provider.dart          # 历史记录管理
│   ├── source_rule_provider.dart      # 播放源管理
│   └── theme_provider.dart            # 主题管理
├── services/                          # 业务服务
│   ├── anime_search_service.dart      # 搜索服务 V2（已重构）
│   ├── anime_detail_service.dart      # 详情服务（智能集数提取）
│   ├── bangumi_api_service.dart       # Bangumi API 服务
│   ├── bangumi_calendar_service.dart  # 番剧日历服务
│   ├── bangumi_comment_service.dart   # 评论服务
│   ├── cache_manager.dart             # 缓存管理
│   ├── app_lifecycle_service.dart     # 应用生命周期
│   ├── video_extractor.dart           # 视频提取器 V2（已重构）
│   ├── spa_episode_extractor.dart     # SPA 页面集数提取器
│   ├── search/                        # 搜索服务 V2（模块化）
│   │   ├── anime_search_service_v2.dart  # 搜索协调器
│   │   ├── html_fetcher.dart             # HTML 请求（静态）
│   │   ├── html_fetcher_dynamic.dart     # HTML 请求（动态/WebView）
│   │   ├── html_fetcher_hybrid.dart      # HTML 请求（混合模式）
│   │   ├── node_selector.dart            # 节点选择
│   │   ├── node_filter.dart              # 节点过滤
│   │   ├── title_extractor.dart          # 标题提取
│   │   ├── title_validator.dart          # 标题验证
│   │   ├── title_normalizer.dart         # 标题归一化
│   │   ├── result_deduplicator.dart      # 结果去重
│   │   ├── series_detector.dart          # 系列检测
│   │   ├── search_config.dart            # 搜索配置
│   │   └── search_logger.dart            # 搜索日志
│   └── video_extraction/              # 视频提取 V2（模块化）
│       ├── video_extractor_v2.dart       # 提取协调器
│       ├── extraction_logger.dart        # 提取日志
│       ├── url_detector.dart             # URL 检测（支持字节跳动 CDN）
│       ├── javascript_injector.dart      # JS 注入
│       ├── webview_manager.dart          # WebView 管理
│       └── scripts/                      # JavaScript 脚本
│           ├── anti_debug.js             # 反调试脚本
│           └── video_monitor.js          # 视频监控脚本
├── screens/                           # 页面
│   ├── home_screen.dart               # 主页
│   ├── anime_detail_screen.dart       # 详情页
│   ├── bangumi_anime_detail_screen.dart  # Bangumi 详情页
│   ├── anime_calendar_screen.dart     # 番剧日历
│   ├── video_player_screen.dart       # 视频播放页
│   ├── media_kit_video_player_screen.dart  # Media Kit 播放器
│   └── optimized_video_player_screen.dart  # 优化播放器
├── widgets/                           # UI 组件
│   ├── custom_title_bar.dart          # 自定义标题栏
│   ├── simple_title_bar.dart          # 简化标题栏
│   ├── sidebar.dart                   # 侧边栏
│   ├── search_bar.dart                # 搜索栏
│   ├── anime_grid.dart                # 动漫网格
│   ├── anime_card.dart                # 动漫卡片
│   ├── anime_selection_dialog.dart    # 动漫选择对话框
│   ├── source_selection_dialog.dart   # 播放源选择对话框
│   ├── source_selection_sidebar.dart  # 播放源底部弹出栏（带自动搜索）
│   ├── bangumi_comments_section.dart  # 评论区组件
│   ├── skeleton_loader.dart           # 骨架屏加载器
│   └── skeleton_demo.dart             # 骨架屏演示
└── utils/                             # 工具类
    ├── search_normalizer.dart         # 搜索归一化
    └── com_resource_manager.dart      # COM 资源管理

docs/                                  # 文档
├── REFACTORING_ARCHITECTURE.md        # 重构架构文档
├── SEARCH_PRECISION_IMPROVEMENTS.md   # 搜索精度改进
├── V1_VS_V2_COMPARISON.md             # V1 vs V2 对比
├── VIDEO_EXTRACTOR_REFACTORING.md     # 视频提取重构
├── DYNAMIC_LOADING_GUIDE.md           # 动态加载指南
├── DYNAMIC_LOADING_OPTIMIZATION.md    # 动态加载优化
├── BANGUMI_API_OPTIMIZATION.md        # Bangumi API 优化
└── BEFORE_AFTER_COMPARISON.md         # 改进前后对比
```

## 🚀 安装和运行

### 环境要求
- **Flutter SDK** 3.0.0 或更高版本
- **Dart SDK** 3.0.0 或更高版本
- **Windows 10/11** 操作系统
- **Visual Studio 2019+** 或 **Visual Studio Build Tools**（用于 Windows 开发）

### 安装步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd dimenx
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用（调试模式）**
   ```bash
   flutter run -d windows
   ```

4. **构建发布版本**
   ```bash
   flutter build windows --release
   ```

5. **运行发布版本**
   构建完成后，可执行文件位于：
   ```
   build/windows/x64/runner/Release/dimenx.exe
   ```

## 📖 使用说明

### 基本操作
1. **浏览动漫** - 在首页查看所有可用的动漫，支持网格布局
2. **搜索动漫** - 使用顶部搜索栏查找特定动漫，支持多源搜索
3. **查看详情** - 点击动漫卡片查看详细信息，包括简介、评分、集数等
4. **选择播放源** - 在详情页选择不同的播放源
5. **播放视频** - 点击播放按钮或选择特定集数开始观看
6. **收藏动漫** - 点击心形图标添加到收藏列表
7. **查看历史** - 在侧边栏选择历史记录，快速继续观看
8. **番剧日历** - 查看每日更新的番剧时间表
9. **社区评论** - 查看 Bangumi 社区的评论和讨论

### 快捷键
- `Esc` - 退出全屏模式
- `Space` - 播放/暂停视频
- `F` - 切换全屏模式
- `←/→` - 快进/快退
- `↑/↓` - 音量调节

### 播放源管理
- 应用支持自定义播放源规则
- 可以添加、编辑、删除播放源
- 每个播放源包含搜索规则和视频提取规则

## 🏗️ 架构设计

### V2 重构架构

DimenX 采用模块化架构设计，将复杂的业务逻辑拆分为独立的模块，提高代码可维护性和可测试性。

#### 搜索服务架构（V2）
```
AnimeSearchServiceV2 (协调层)
├── HtmlFetcher (HTTP 请求)
├── NodeSelector (节点选择)
├── NodeFilter (节点过滤)
├── TitleExtractor (标题提取)
├── TitleValidator (标题验证)
├── TitleNormalizer (标题归一化)
├── ResultDeduplicator (结果去重)
├── SeriesDetector (系列检测)
├── SearchConfig (配置管理)
└── SearchLogger (日志管理)
```

**改进效果**：
- 代码量减少 59%（1500 行 → 620 行）
- 搜索精度提升至 90%+
- 单个类不超过 80 行
- 职责清晰，易于测试

#### 视频提取架构（V2）
```
VideoExtractorV2 (协调层)
├── ExtractionLogger (日志管理)
├── UrlDetector (URL 检测和验证)
├── JavaScriptInjector (JS 脚本注入)
├── WebViewManager (WebView 生命周期)
└── scripts/
    ├── anti_debug.js (反调试)
    └── video_monitor.js (视频监控)
```

**特性**：
- 模块化设计，职责分离
- 支持多层 iframe 递归解析
- 智能超时和提前完成策略
- 反调试和 URL 监控机制

### 设计原则
- **单一职责原则（SRP）**：每个类只做一件事
- **开闭原则（OCP）**：对扩展开放，对修改关闭
- **依赖倒置原则（DIP）**：依赖抽象而非具体实现
- **接口隔离原则（ISP）**：接口最小化，职责单一

详细架构文档请参考：
- [搜索服务重构架构](docs/REFACTORING_ARCHITECTURE.md)
- [搜索精度改进](docs/SEARCH_PRECISION_IMPROVEMENTS.md)
- [V1 vs V2 对比](docs/V1_VS_V2_COMPARISON.md)

## 💻 开发说明

### 添加新的播放源
1. 在 `lib/models/source_rule.dart` 中定义新的规则
2. 配置搜索规则（XPath/CSS 选择器）
3. 配置视频提取规则
4. 在 `lib/providers/source_rule_provider.dart` 中注册新规则

### 自定义搜索配置
修改 `lib/services/search/search_config.dart`：
```dart
class SearchConfig {
  // 添加自定义黑名单
  static const titleBlacklist = [
    ...默认黑名单,
    '你的自定义关键词',
  ];
  
  // 调整验证阈值
  static const int minTitleLength = 2;
  static const int maxTitleLength = 100;
}
```

### 自定义主题
1. 修改 `lib/providers/theme_provider.dart` 中的主题配置
2. 更新颜色常量和样式定义

### 添加新功能
1. 在相应的 Provider 中添加业务逻辑
2. 在 `lib/services/` 中创建新的服务类
3. 创建或修改 UI 组件
4. 更新路由和导航逻辑

### 调试模式
启用详细日志查看运行过程：
```dart
// 搜索服务
final searchService = AnimeSearchServiceV2(
  enableLogging: true,
  verboseLogging: true,
);

// 视频提取
final result = await extractor.extractVideoUrl(
  url,
  rule,
  enableLogging: true,
  verboseLogging: true,
);
```

## ⚠️ 注意事项

- 本项目需要配置有效的动漫播放源才能正常使用
- 视频链接提取依赖于播放源的网页结构，可能需要定期更新规则
- 部分播放源可能需要特殊的网络环境才能访问
- 请确保遵守相关的版权法律法规，仅用于学习和研究目的
- 建议在良好的网络环境下使用，以获得最佳体验

## 🔧 常见问题

### 搜索不到结果？
- 检查播放源规则是否正确配置
- 尝试使用不同的播放源
- 启用调试日志查看详细信息

### 视频无法播放？
- 确认视频链接提取成功
- 检查网络连接是否正常
- 尝试使用不同的播放器（media_kit/video_player）
- 查看提取日志排查问题

### 应用启动失败？
- 确认 Flutter SDK 版本符合要求
- 运行 `flutter doctor` 检查环境配置
- 清理项目后重新构建：`flutter clean && flutter pub get`

## 📊 性能优化

- **图片缓存**：使用 cached_network_image 缓存封面图片
- **搜索优化**：V2 架构提升搜索速度和精度
- **视频提取**：智能超时和提前完成策略，减少等待时间
- **内存管理**：及时释放 WebView 和其他资源
- **骨架屏**：优雅的加载状态展示，提升用户体验

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

### 贡献流程
1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

### 代码规范
- 遵循 Dart 官方代码风格
- 使用有意义的变量和函数命名
- 添加必要的注释和文档
- 保持单一职责原则
- 编写可测试的代码

### 提交规范
- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

## 📝 更新日志

### V2.1.0 (2026-02-07) 🎉 重大更新
#### 🚀 播放体验优化
- ✨ **全新播放源选择界面** - 底部弹出式设计，更符合现代 UI 规范
- ✨ **自动搜索和在线检测** - 打开播放源选择时自动搜索所有规则，实时显示在线状态
- ✨ **TabBar 路线切换** - 使用 Flutter 原生 TabBar 组件，支持多路线平滑切换
- ✨ **智能集数选择** - 先选择路线，再选择集数，流程更清晰
- ✨ **右侧滑出式集数选择器** - 4列网格布局，快速定位集数
- ✨ **自动播放控制** - 进入播放器后等待用户选择集数，不再自动播放

#### ⚡ 性能优化
- ⚡ **视频提取速度提升** - 发现视频链接后 100ms 快速完成，不再等待完整页面加载
- ⚡ **搜索缓存优化** - 只缓存有效结果（>200字符），2分钟有效期
- ⚡ **动态加载优化** - 超时从 20s 降至 15s，等待时间从 5s 降至 3s
- ⚡ **智能内容稳定性检测** - 检测页面内容是否稳定，避免过早返回

#### 🔧 功能增强
- ✨ **字节跳动 CDN 支持** - 识别 bytetos.com、imcloud-file 等签名链接
- ✨ **智能 URL 拼接** - 从详情页 URL 提取域名，避免错误拼接
- ✨ **并发控制** - 动态加载最多同时 2 个请求，避免资源浪费
- ✨ **资源加载优化** - 禁用图片、CSS、字体加载，加快页面渲染

#### 🐛 Bug 修复
- 🐛 修复播放源 URL 拼接错误（使用错误的 baseURL）
- 🐛 修复视频提取后继续执行无用操作的问题
- 🐛 修复搜索结果缓存无效结果的问题
- 🐛 修复动态加载超时时间过长的问题

### V2.0.0 (2026-01-31)
- ✨ 重构搜索服务架构，搜索精度提升至 90%+
- ✨ 重构视频提取架构，采用模块化设计
- ✨ 新增番剧日历功能
- ✨ 集成 Bangumi API，支持评论查看
- ✨ 新增骨架屏加载效果
- 🐛 修复搜索结果重复问题
- 🐛 修复视频提取超时问题
- ⚡ 优化搜索性能，减少 59% 代码量
- ⚡ 优化视频提取速度，智能提前完成
- 📚 完善项目文档

### V1.0.0
- 🎉 初始版本发布
- ✨ 基础动漫浏览和搜索功能
- ✨ 视频播放功能
- ✨ 收藏和历史记录功能

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- **Flutter 团队** - 提供优秀的跨平台框架
- **Bangumi** - 提供番剧数据 API
- **所有开源依赖包的维护者** - 提供强大的工具和库
- **动漫社区** - 支持和反馈

## 📮 联系方式

- **开发团队**: 由Sakurayuki开发
- **问题反馈**: 请在 GitHub Issues 中提交
- **QQ**:3917474045

---

**免责声明**: 本项目仅用于学习和研究目的，请确保在使用时遵守当地法律法规和版权规定。本项目不提供任何视频内容，所有内容均来自第三方播放源。

