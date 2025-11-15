# DimenX

一个基于Flutter开发的Windows桌面端动漫观看应用，类似Kazumi的功能。

## 功能特性

### 🎬 核心功能
- **动漫浏览** - 精美的网格布局展示动漫列表
- **智能搜索** - 支持按标题、描述、类型搜索动漫
- **视频播放** - 内置视频播放器，支持全屏播放
- **收藏管理** - 收藏喜爱的动漫，本地持久化存储
- **观看历史** - 自动记录观看历史，支持清除功能
- **自定义规则** - 支持添加不同的动漫播放源(不为最终version)

### 🖥️ 桌面端优化
- **自定义标题栏** - 现代化的无边框窗口设计
- **响应式布局** - 适配不同屏幕尺寸
- **流畅动画** - 卡片悬停效果和页面切换动画
- **深色主题** - 护眼的深色界面设计

### 🎨 用户界面
- **侧边栏导航** - 清晰的功能分类
- **动漫卡片** - 显示封面、评分、类型等信息
- **详情页面** - 完整的动漫信息展示
- **播放控制** - 集成播放控制和集数选择

## 技术栈

- **Flutter** - 跨平台UI框架
- **Provider** - 状态管理
- **Video Player** - 视频播放功能
- **Chewie** - 视频播放器UI组件
- **Cached Network Image** - 图片缓存
- **SharedPreferences** - 本地数据存储
- **Window Manager** - 窗口管理
- **Bitsdojo Window** - 自定义窗口装饰

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   └── anime.dart
├── providers/                # 状态管理
│   ├── anime_provider.dart
│   ├── favorites_provider.dart
│   └── history_provider.dart
├── screens/                  # 页面
│   ├── home_screen.dart
│   ├── anime_detail_screen.dart
│   └── video_player_screen.dart
└── widgets/                  # 组件
    ├── custom_title_bar.dart
    ├── sidebar.dart
    ├── search_bar.dart
    ├── anime_grid.dart
    └── anime_card.dart
```

## 安装和运行

### 环境要求
- Flutter SDK 3.0.0+
- Windows 10/11
- Visual Studio 2019+ (用于Windows开发)

### 安装步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd AnimeHUBX
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   flutter run -d windows
   ```

4. **构建发布版本**
   ```bash
   flutter build windows --release
   ```

## 使用说明

### 基本操作
1. **浏览动漫** - 在首页查看所有可用的动漫
2. **搜索动漫** - 使用顶部搜索栏查找特定动漫
3. **查看详情** - 点击动漫卡片查看详细信息
4. **播放视频** - 在详情页点击播放按钮或选择特定集数
5. **收藏动漫** - 点击心形图标添加到收藏
6. **查看历史** - 在侧边栏选择历史记录

### 快捷键
- `Esc` - 退出全屏模式
- `Space` - 播放/暂停视频
- `F` - 切换全屏模式

## 开发说明

### 添加新的动漫源
1. 修改 `lib/providers/anime_provider.dart` 中的数据源
2. 实现相应的API调用逻辑
3. 更新数据模型以适配新的数据格式

### 自定义主题
1. 修改 `lib/main.dart` 中的主题配置
2. 更新颜色常量和样式定义

### 添加新功能
1. 在相应的Provider中添加业务逻辑
2. 创建或修改UI组件
3. 更新路由和导航逻辑

## 注意事项

- 本项目使用模拟数据，实际使用时需要接入真实的动漫数据源
- 视频播放功能使用示例视频，需要配置实际的视频源
- 请确保遵守相关的版权法律法规

## 贡献指南

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 致谢

- Flutter团队提供的优秀框架
- 所有开源依赖包的维护者
- 动漫社区的支持和反馈

---
本产品由Axis corx Team开发
**免责声明**: 本项目仅用于学习和研究目的，请确保在使用时遵守当地法律法规和版权规定。
