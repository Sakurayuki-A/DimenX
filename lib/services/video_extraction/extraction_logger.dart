import 'package:flutter/foundation.dart';

/// 视频提取日志管理器
class ExtractionLogger {
  final List<String> _logs = [];
  final bool enabled;
  final bool verbose;

  ExtractionLogger({
    this.enabled = true,
    this.verbose = false,
  });

  void info(String message) {
    if (enabled) {
      _addLog('[INFO] $message');
    }
  }

  void success(String message) {
    if (enabled) {
      _addLog('[SUCCESS] $message');
    }
  }

  void warning(String message) {
    if (enabled) {
      _addLog('[WARNING] $message');
    }
  }

  void error(String message) {
    if (enabled) {
      _addLog('[ERROR] $message');
    }
  }

  void debug(String message) {
    if (enabled && verbose) {
      _addLog('[DEBUG] $message');
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    if (kDebugMode) {
      print('VideoExtractor: $logMessage');
    }
  }

  List<String> getLogs() => List.from(_logs);

  void clear() => _logs.clear();
}
