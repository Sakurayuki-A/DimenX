import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: const Color(0xFF2d2d2d),
      child: Row(
        children: [
          // 应用图标和标题
          Expanded(
            child: MoveWindow(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Row(
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      color: Colors.blue,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AnimeHubX',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 窗口控制按钮
          Row(
            children: [
              // 最小化按钮
              WindowButton(
                colors: WindowButtonColors(
                  iconNormal: Colors.white70,
                  mouseOver: const Color(0xFF404040),
                  mouseDown: const Color(0xFF202020),
                  iconMouseOver: Colors.white,
                  iconMouseDown: Colors.white,
                ),
                padding: const EdgeInsets.all(10),
                iconBuilder: (buttonContext) => MinimizeIcon(
                  color: buttonContext.iconColor,
                ),
                onPressed: () => appWindow.minimize(),
              ),
              
              // 最大化/还原按钮
              WindowButton(
                colors: WindowButtonColors(
                  iconNormal: Colors.white70,
                  mouseOver: const Color(0xFF404040),
                  mouseDown: const Color(0xFF202020),
                  iconMouseOver: Colors.white,
                  iconMouseDown: Colors.white,
                ),
                padding: const EdgeInsets.all(10),
                iconBuilder: (buttonContext) => MaximizeIcon(
                  color: buttonContext.iconColor,
                ),
                onPressed: () => appWindow.maximizeOrRestore(),
              ),
              
              // 关闭按钮
              WindowButton(
                colors: WindowButtonColors(
                  iconNormal: Colors.white70,
                  mouseOver: const Color(0xFFE81123),
                  mouseDown: const Color(0xFFF1707A),
                  iconMouseOver: Colors.white,
                  iconMouseDown: Colors.white,
                ),
                padding: const EdgeInsets.all(10),
                iconBuilder: (buttonContext) => CloseIcon(
                  color: buttonContext.iconColor,
                ),
                onPressed: () => appWindow.close(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
