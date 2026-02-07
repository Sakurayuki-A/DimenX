import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 用户头像区域 - 简化版
          Container(
            padding: const EdgeInsets.all(12),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.person,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          
          // 导航菜单
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.home,
                    title: '首页',
                    index: 0,
                    isSelected: selectedIndex == 0,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.search,
                    title: '搜索',
                    index: 4,
                    isSelected: selectedIndex == 4,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_today,
                    title: '时间表',
                    index: 5,
                    isSelected: selectedIndex == 5,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.favorite,
                    title: '收藏',
                    index: 1,
                    isSelected: selectedIndex == 1,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.history,
                    title: '历史',
                    index: 2,
                    isSelected: selectedIndex == 2,
                  ),
                ],
              ),
            ),
          ),
          
          // 设置菜单 - 移到底部
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildMenuItem(
              context,
              icon: Icons.settings,
              title: '设置',
              index: 3,
              isSelected: selectedIndex == 3,
            ),
          ),
          
          // 底部信息 - 简化版
          Container(
            padding: const EdgeInsets.all(8),
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required bool isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      transform: isSelected ? Matrix4.translationValues(4.0, 0.0, 0.0) : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected 
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF008080).withOpacity(0.15) // 深色模式下使用青色背景
                : Theme.of(context).primaryColor.withOpacity(0.15))
            : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onItemSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.1 : 1.0,
              child: Icon(
                icon,
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF008080) // 深色模式下选中时使用青色
                        : Theme.of(context).primaryColor)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey.withOpacity(0.7)),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
