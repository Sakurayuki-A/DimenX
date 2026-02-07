class Anime {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String videoUrl;
  final List<String> genres;
  final double rating;
  final int year;
  final String status;
  final int episodes;
  final List<Episode>? episodeList;
  final String detailUrl; // 详情页URL
  final List<String> tags; // 标签列表
  final int episodeCount; // 总集数
  final String source; // 数据来源
  final int? rank; // Bangumi排名
  final String airDate; // 播出日期（完整日期字符串）

  Anime({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.videoUrl = '',
    this.genres = const [],
    required this.rating,
    required this.year,
    required this.status,
    this.episodes = 0,
    this.episodeList,
    this.detailUrl = '',
    this.tags = const [],
    this.episodeCount = 0,
    this.source = '',
    this.rank,
    this.airDate = '',
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      rating: (json['rating'] ?? 0.0).toDouble(),
      year: json['year'] ?? 0,
      status: json['status'] ?? '',
      episodes: json['episodes'] ?? 0,
      episodeList: json['episodeList'] != null 
          ? (json['episodeList'] as List).map((e) => Episode.fromJson(e)).toList()
          : null,
      detailUrl: json['detailUrl'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      episodeCount: json['episodeCount'] ?? 0,
      source: json['source'] ?? '',
      rank: json['rank'],
      airDate: json['airDate'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'genres': genres,
      'rating': rating,
      'year': year,
      'status': status,
      'episodes': episodes,
      'episodeList': episodeList?.map((e) => e.toJson()).toList(),
      'detailUrl': detailUrl,
      'tags': tags,
      'episodeCount': episodeCount,
      'source': source,
      'rank': rank,
      'airDate': airDate,
    };
  }

  Anime copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? videoUrl,
    List<String>? genres,
    double? rating,
    int? year,
    String? status,
    int? episodes,
    List<Episode>? episodeList,
    String? detailUrl,
    List<String>? tags,
    int? episodeCount,
    String? source,
    int? rank,
    String? airDate,
  }) {
    return Anime(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      status: status ?? this.status,
      episodes: episodes ?? this.episodes,
      episodeList: episodeList ?? this.episodeList,
      detailUrl: detailUrl ?? this.detailUrl,
      tags: tags ?? this.tags,
      episodeCount: episodeCount ?? this.episodeCount,
      source: source ?? this.source,
      rank: rank ?? this.rank,
      airDate: airDate ?? this.airDate,
    );
  }
}

class Episode {
  final String id;
  final String title;
  final String videoUrl;
  final int episodeNumber;
  final String thumbnail;
  final Duration duration;

  Episode({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.episodeNumber,
    required this.thumbnail,
    required this.duration,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      episodeNumber: json['episodeNumber'] ?? 0,
      thumbnail: json['thumbnail'] ?? '',
      duration: Duration(seconds: json['duration'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'videoUrl': videoUrl,
      'episodeNumber': episodeNumber,
      'thumbnail': thumbnail,
      'duration': duration.inSeconds,
    };
  }
}
