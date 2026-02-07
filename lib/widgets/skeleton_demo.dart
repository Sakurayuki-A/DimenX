import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

/// 骨架屏演示页面（用于测试和预览）
class SkeletonDemo extends StatelessWidget {
  const SkeletonDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('骨架屏加载动画演示'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '动漫卡片骨架屏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const AnimeCardSkeleton(),
            
            const SizedBox(height: 32),
            
            const Text(
              '文本行骨架屏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const TextLineSkeleton(width: double.infinity),
            const SizedBox(height: 8),
            const TextLineSkeleton(width: 200),
            const SizedBox(height: 8),
            const TextLineSkeleton(width: 150),
            
            const SizedBox(height: 32),
            
            const Text(
              '详情页骨架屏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const DetailPageSkeleton(),
          ],
        ),
      ),
    );
  }
}
