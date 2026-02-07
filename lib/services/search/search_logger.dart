/// 搜索日志管理 - 统一的日志接口
class SearchLogger {
  final bool enabled;
  final bool verbose;

  const SearchLogger({
    this.enabled = true,
    this.verbose = false,
  });

  void info(String message) {
    if (enabled) print('ℹ️ $message');
  }

  void success(String message) {
    if (enabled) print('✓ $message');
  }

  void warning(String message) {
    if (enabled) print('⚠️ $message');
  }

  void error(String message) {
    if (enabled) print('✗ $message');
  }

  void debug(String message) {
    if (enabled && verbose) print('🔍 $message');
  }

  void filter(String message) {
    if (enabled && verbose) print('🔥 $message');
  }
}
