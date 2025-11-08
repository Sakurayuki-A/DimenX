import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/anime.dart';
import 'anime_card.dart';

class AnimeGrid extends StatelessWidget {
  final List<Anime> animes;
  final Function(Anime) onAnimeSelected;

  const AnimeGrid({
    super.key,
    required this.animes,
    required this.onAnimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: MasonryGridView.count(
        crossAxisCount: _getCrossAxisCount(context),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        itemCount: animes.length,
        shrinkWrap: true, // 关键：让GridView适应内容高度
        physics: const NeverScrollableScrollPhysics(), // 禁用GridView自己的滚动
        itemBuilder: (context, index) {
          return AnimeCard(
            anime: animes[index],
            onTap: () => onAnimeSelected(animes[index]),
          );
        },
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 6;
    if (width > 1200) return 5;
    if (width > 1000) return 4;
    if (width > 800) return 3;
    return 2;
  }
}
