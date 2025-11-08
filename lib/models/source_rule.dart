class SourceRule {
  final String id;
  final String name;
  final String version;
  final String baseURL;
  final String searchURL;
  final String searchList;
  final String searchName;
  final String searchResult;
  final String imgRoads;
  final String chapterRoads;
  final String chapterResult;

  SourceRule({
    required this.id,
    required this.name,
    required this.version,
    required this.baseURL,
    required this.searchURL,
    required this.searchList,
    required this.searchName,
    required this.searchResult,
    required this.imgRoads,
    required this.chapterRoads,
    required this.chapterResult,
  });

  factory SourceRule.fromJson(Map<String, dynamic> json) {
    return SourceRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      version: json['version'] ?? '',
      baseURL: json['baseURL'] ?? '',
      searchURL: json['searchURL'] ?? '',
      searchList: json['searchList'] ?? '',
      searchName: json['searchName'] ?? '',
      searchResult: json['searchResult'] ?? '',
      imgRoads: json['imgRoads'] ?? '',
      chapterRoads: json['chapterRoads'] ?? '',
      chapterResult: json['chapterResult'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'version': version,
      'baseURL': baseURL,
      'searchURL': searchURL,
      'searchList': searchList,
      'searchName': searchName,
      'searchResult': searchResult,
      'imgRoads': imgRoads,
      'chapterRoads': chapterRoads,
      'chapterResult': chapterResult,
    };
  }

  SourceRule copyWith({
    String? id,
    String? name,
    String? version,
    String? baseURL,
    String? searchURL,
    String? searchList,
    String? searchName,
    String? searchResult,
    String? imgRoads,
    String? chapterRoads,
    String? chapterResult,
  }) {
    return SourceRule(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      baseURL: baseURL ?? this.baseURL,
      searchURL: searchURL ?? this.searchURL,
      searchList: searchList ?? this.searchList,
      searchName: searchName ?? this.searchName,
      searchResult: searchResult ?? this.searchResult,
      imgRoads: imgRoads ?? this.imgRoads,
      chapterRoads: chapterRoads ?? this.chapterRoads,
      chapterResult: chapterResult ?? this.chapterResult,
    );
  }
}
