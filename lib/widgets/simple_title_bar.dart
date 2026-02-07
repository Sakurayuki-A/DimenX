import 'package:flutter/material.dart';

class SimpleTitleBar extends StatelessWidget {
  const SimpleTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: Row(
        children: [
          // 应用图标和标题
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_filled,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AnimeHubX',
                    style: TextStyle(
                      fontFamily: 'Microsoft YaHei',
                      color: Theme.of(context).appBarTheme.titleTextStyle?.color ?? Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 窗口控制按钮（简化版）
          Row(
            children: [
              // 最小化按钮
              IconButton(
                onPressed: () {
                  // 在实际应用中，这里会调用系统API最小化窗口
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('最小化功能需要系统API支持'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.minimize, color: Colors.white70, size: 16),
                iconSize: 16,
                padding: const EdgeInsets.all(8),
              ),
              
              // 最大化按钮
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('最大化功能需要系统API支持'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.crop_square, color: Colors.white70, size: 16),
                iconSize: 16,
                padding: const EdgeInsets.all(8),
              ),
              
              // 关闭按钮
              IconButton(
                onPressed: () {
                  // 显示确认对话框
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('确认退出'),
                      content: const Text('确定要关闭AnimeHubX吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // 在实际应用中，这里会调用系统API关闭应用
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('关闭功能需要系统API支持'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                iconSize: 16,
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
