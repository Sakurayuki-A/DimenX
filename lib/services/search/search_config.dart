/// 搜索配置 - 可配置化的规则和黑名单
class SearchConfig {
  // 节点过滤黑名单
  static const nodeClassBlacklist = [
    'header', 'footer', 'nav', 'menu', 'sidebar', 'banner',
    'ad', 'advertisement', 'popup', 'modal', 'dialog',
    'login', 'register', 'user', 'account', 'profile',
    'search-bar', 'search-box', 'search-input', 'filter', 'sort', 'pagination',
    'copyright', 'feedback', 'contact', 'about',
    'download', 'app', 'qrcode', 'share',
    'comment', 'reply', 'message', 'notification',
  ];

  // 垃圾内容关键词
  static const garbageKeywords = [
    'app下载', 'app 下载', '下载app', '客户端',
    '问题反馈', '意见反馈', '联系我们', '关于我们',
    '用户协议', '隐私政策', '免责声明',
    '签到', '打卡', '积分', '会员',
    '破解', '涩涩', '💋', '🔞', '成人',
    '抖音', '快手', '直播',
    '广告', '推广', '赞助',
  ];

  // 标题黑名单
  static const titleBlacklist = [
    // 导航关键词
    '首页', '主页', 'home', '返回',
    '分类', '排行', '榜单', '推荐',
    '最新', '热门', '完结', '连载',
    '国产', '日本', '欧美', '其他',
    '泡面番', '剧场版', '特别篇',
    '登录', '注册', '搜索',
    // 功能性关键词
    'app下载', '问题反馈', '联系我们', '用户协议',
    '签到', '会员中心', '我的收藏',
    // 不良内容
    '破解版', '涩涩', '成人', '18+',
    '抖音', '快手', '直播',
    '💋', '🔞', '❤️',
  ];

  // 系列作品匹配模式
  static const seasonPatterns = [
    r'第([一二三四五六七八九十\d]+)季',
    r'season\s*(\d+)',
    r's(\d+)',
    r'(\d+)nd\s+season',
    r'(\d+)rd\s+season',
    r'(\d+)th\s+season',
  ];

  static const specialVersions = [
    '剧场版', '电影版', 'movie', 'film',
    'ova', 'oad', 'sp', 'special',
    '总集篇', '番外', '外传',
  ];

  // 验证阈值
  static const int minTitleLength = 2;
  static const int maxTitleLength = 100;
  static const double maxSpecialCharRatio = 0.3;
  static const int maxTextLength = 500;
}
