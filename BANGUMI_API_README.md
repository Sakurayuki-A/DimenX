# 简化的Bangumi API服务

## 概述

重新制作的BangumiAPI调用模块，删除了不必要的复杂逻辑，保留核心功能，提供简洁高效的API调用服务。

## 主要改进

### 🎯 **简化的架构**
- **移除复杂逻辑**: 删除了复杂的相关性评分算法
- **移除过滤机制**: 删除了日漫检测和过滤逻辑
- **统一解析方法**: 使用单一的`_parseAnime`方法处理所有数据
- **简化错误处理**: 统一的异常处理机制

### 🚀 **性能优化**
- **超时控制**: 所有请求设置10秒超时
- **减少网络请求**: 移除不必要的API调用
- **内存优化**: 减少对象创建和数据处理

### 🔧 **核心功能**

#### 1. 获取当季动画
```dart
Future<List<Anime>> getSeasonalAnime({int limit = 20})
```
- 从Bangumi Calendar API获取当季播出的动画
- 自动过滤非动画内容（type != 2）
- 支持限制返回数量

#### 2. 搜索动画
```dart
Future<List<Anime>> searchAnime(String keyword, {int limit = 20})
```
- 根据关键词搜索动画
- 自动处理空关键词
- URL编码处理中文搜索

#### 3. 获取动画详情
```dart
Future<Anime?> getAnimeDetail(String bangumiId)
```
- 根据BangumiID获取详细信息
- 使用v0 API获取更完整的数据

## API对比

### 原版API（复杂）
- **567行代码**
- 复杂的相关性评分算法
- 日漫检测和过滤机制
- 详细的infobox信息提取
- 多个重复的解析方法

### 简化版API（精简）
- **162行代码**（减少71%）
- 直接返回搜索结果
- 统一的数据解析
- 核心功能保留
- 更好的可维护性

## 使用方法

### 基本用法
```dart
final bangumiService = BangumiApiService();

// 获取当季动画
final seasonalAnime = await bangumiService.getSeasonalAnime(limit: 10);

// 搜索动画
final searchResults = await bangumiService.searchAnime('进击的巨人');

// 获取详情
final animeDetail = await bangumiService.getAnimeDetail('12345');
```

### 错误处理
```dart
try {
  final animeList = await bangumiService.getSeasonalAnime();
  // 处理结果
} catch (e) {
  print('获取动画失败: $e');
  // 返回空列表，不会抛出异常
}
```

## 数据结构

### 返回的Anime对象包含：
- `id`: Bangumi ID（带bangumi_前缀）
- `title`: 动画标题（优先中文名）
- `imageUrl`: 封面图片URL
- `description`: 简介
- `rating`: 评分（0.0-10.0）
- `year`: 年份
- `status`: 状态（即将播出/连载中/已完结）
- `episodes`: 集数
- `source`: 数据来源（固定为'Bangumi'）

## 网络配置

### 请求头设置
- `User-Agent`: AnimeHUBX/1.0.0
- `Accept`: application/json
- `Timeout`: 10秒

### API端点
- 当季动画: `https://api.bgm.tv/calendar`
- 搜索: `https://api.bgm.tv/search/subject/{keyword}?type=2`
- 详情: `https://api.bgm.tv/v0/subjects/{id}`

## 移除的功能

### 已删除的复杂功能
1. **相关性评分算法** - 复杂的搜索结果排序
2. **日漫过滤机制** - 自动过滤非日本动画
3. **详细infobox解析** - 复杂的元数据提取
4. **多重数据验证** - 过度的数据校验
5. **热门动画API** - 重复的功能接口

### 保留的核心功能
1. **基础数据解析** - 标题、图片、简介等
2. **状态判断** - 播出状态识别
3. **年份提取** - 从日期字符串提取年份
4. **错误处理** - 统一的异常处理

## 测试

### 单元测试
```bash
flutter test test/bangumi_api_test.dart
```

### 测试覆盖
- API服务创建
- 获取当季动画
- 搜索功能
- 详情获取
- 错误处理

## 性能指标

### 代码量对比
- **原版**: 567行 → **简化版**: 162行
- **减少**: 71%的代码量
- **方法数**: 从15个减少到6个

### 功能对比
- **保留**: 3个核心API方法
- **移除**: 12个辅助方法
- **简化**: 数据解析逻辑

## 兼容性

### 向后兼容
- 保持相同的方法签名
- 返回相同的数据结构
- 兼容现有调用代码

### 破坏性变更
- 移除了`getPopularAnime`方法
- 简化了搜索结果排序
- 移除了详细的标签和类型信息

## 未来计划

### 可能的增强
1. **缓存机制** - 添加本地缓存
2. **批量请求** - 支持批量获取详情
3. **图片代理** - 处理图片访问问题
4. **离线支持** - 本地数据存储

## 更新日志

### v2.0.0 (2024-11-14)
- 🎉 完全重写BangumiAPI服务
- ✂️ 删除71%的冗余代码
- 🚀 提升API调用性能
- 🔧 简化数据解析逻辑
- 📝 统一错误处理机制
- 🧪 添加完整单元测试

## 贡献指南

### 开发原则
1. **保持简洁** - 避免过度设计
2. **核心功能** - 专注主要用例
3. **性能优先** - 减少不必要的处理
4. **易于维护** - 清晰的代码结构

### 代码规范
- 遵循Dart代码规范
- 保持方法简洁（<50行）
- 添加适当的注释
- 编写对应的测试

## 许可证

本项目采用MIT许可证，详见LICENSE文件。
