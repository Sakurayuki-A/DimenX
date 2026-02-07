import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSearch;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar>
    with TickerProviderStateMixin {
  late AnimationController _focusController;
  late AnimationController _clearController;
  late Animation<double> _focusAnimation;
  late Animation<double> _clearAnimation;
  late Animation<Color?> _borderColorAnimation;
  
  bool _isFocused = false;
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    _focusController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _clearController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _focusAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeInOut,
    ));
    
    _clearAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _clearController,
      curve: Curves.elasticOut,
    ));
    
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
        
        if (_isFocused) {
          if (mounted && !_focusController.isAnimating) {
            _focusController.forward();
          }
        } else {
          if (mounted && !_focusController.isAnimating) {
            _focusController.reverse();
          }
        }
      }
    });
    
    widget.controller.addListener(() {
      if (mounted) {
        if (widget.controller.text.isNotEmpty) {
          if (!_clearController.isAnimating) {
            _clearController.forward();
          }
        } else {
          if (!_clearController.isAnimating) {
            _clearController.reverse();
          }
        }
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 在这里初始化依赖于Theme的动画
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _borderColorAnimation = ColorTween(
      begin: Colors.grey.withOpacity(0.3),
      end: isDark ? Colors.white.withOpacity(0.8) : Theme.of(context).primaryColor.withOpacity(0.6),
    ).animate(CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _focusController.dispose();
    _clearController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_focusController, _clearController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _focusAnimation.value,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: _borderColorAnimation.value ?? Colors.grey.withOpacity(0.3),
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: _isFocused ? [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white.withOpacity(0.3)
                      : Theme.of(context).primaryColor.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ] : [],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.search,
                    color: _isFocused 
                        ? (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Theme.of(context).primaryColor)
                        : Colors.grey,
                    size: _isFocused ? 26 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索动漫...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: (value) {
                      widget.onSearch(value);
                    },
                    onSubmitted: (value) {
                      widget.onSearch(value);
                    },
                  ),
                ),
                AnimatedScale(
                  scale: _clearAnimation.value,
                  duration: const Duration(milliseconds: 200),
                  child: widget.controller.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            widget.controller.clear();
                            widget.onSearch('');
                          },
                          icon: Icon(
                            Icons.clear,
                            color: _isFocused 
                                ? (Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Theme.of(context).primaryColor)
                                : Colors.grey,
                            size: 20,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
