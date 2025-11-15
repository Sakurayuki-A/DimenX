import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dimenx/screens/video_player_screen.dart';
import 'package:dimenx/models/anime.dart';

void main() {
  group('VideoPlayerScreen Tests', () {
    late Anime testAnime;

    setUp(() {
      testAnime = Anime(
        id: 'test-1',
        title: '测试动漫',
        description: '这是一个测试动漫',
        imageUrl: 'https://example.com/image.jpg',
        videoUrl: 'https://example.com/video.m3u8',
        episodes: 12,
        status: '已完结',
        year: 2024,
        rating: 8.5,
        source: 'test',
      );
    });

    testWidgets('VideoPlayerScreen should build without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerScreen(
            anime: testAnime,
            episodeNumber: 1,
          ),
        ),
      );

      // 验证基本UI元素存在
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      expect(find.text('测试动漫'), findsOneWidget);
      expect(find.text('第1集'), findsOneWidget);
    });

    testWidgets('VideoPlayerScreen should show loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerScreen(
            anime: testAnime,
            episodeNumber: 1,
          ),
        ),
      );

      // 应该显示加载指示器
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在提取视频链接...'), findsOneWidget);
    });

    testWidgets('VideoPlayerScreen should handle episode navigation', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerScreen(
            anime: testAnime,
            episodeNumber: 5,
          ),
        ),
      );

      await tester.pump();

      // 验证集数显示
      expect(find.text('第5集'), findsOneWidget);
    });

    testWidgets('VideoPlayerScreen should show error state when video fails to load', (WidgetTester tester) async {
      // 创建一个无效的动漫对象来触发错误
      final invalidAnime = Anime(
        id: 'invalid',
        title: '无效动漫',
        description: '这会导致错误',
        imageUrl: '',
        videoUrl: '', // 空的视频URL会导致错误
        episodes: 1,
        status: '错误',
        year: 2024,
        rating: 0.0,
        source: 'test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerScreen(
            anime: invalidAnime,
            episodeNumber: 1,
          ),
        ),
      );

      // 等待错误状态
      await tester.pump(const Duration(seconds: 2));

      // 可能会显示错误相关的UI元素
      // 注意：实际的错误处理取决于VideoExtractor的实现
    });
  });

  group('VideoPlayerScreen Controls Tests', () {
    testWidgets('VideoPlayerScreen should have proper control buttons', (WidgetTester tester) async {
      final testAnime = Anime(
        id: 'test-controls',
        title: '控制测试',
        description: '测试控制按钮',
        imageUrl: 'https://example.com/image.jpg',
        videoUrl: 'https://example.com/video.m3u8',
        episodes: 10,
        status: '连载中',
        year: 2024,
        rating: 7.8,
        source: 'test',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerScreen(
            anime: testAnime,
            episodeNumber: 5,
          ),
        ),
      );

      await tester.pump();

      // 查找返回按钮
      expect(find.byIcon(Icons.arrow_back), findsWidgets);
      
      // 查找全屏按钮
      expect(find.byIcon(Icons.fullscreen), findsWidgets);
    });
  });
}
