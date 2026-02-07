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
  
  // 高级设置
  final bool enableDynamicLoading; // 是否启用动态加载（WebView渲染）
  
  // 路线配置
  final String roadList; // 路线列表的 XPath，用于定位所有路线元素
  final String roadName; // 路线名称的 XPath，用于从路线元素中提取名称

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
    this.enableDynamicLoading = false, // 默认关闭，避免影响性能
    this.roadList = '', // 路线列表 XPath
    this.roadName = '', // 路线名称 XPath
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
      enableDynamicLoading: json['enableDynamicLoading'] ?? false,
      roadList: json['roadList'] ?? '',
      roadName: json['roadName'] ?? '',
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
      'enableDynamicLoading': enableDynamicLoading,
      'roadList': roadList,
      'roadName': roadName,
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
    bool? enableDynamicLoading,
    String? roadList,
    String? roadName,
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
      enableDynamicLoading: enableDynamicLoading ?? this.enableDynamicLoading,
      roadList: roadList ?? this.roadList,
      roadName: roadName ?? this.roadName,
    );
  }
}
