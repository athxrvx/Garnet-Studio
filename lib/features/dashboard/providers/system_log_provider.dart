import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum LogLevel { info, success, warn, error }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }
}

class SystemLogNotifier extends Notifier<List<LogEntry>> {
  @override
  List<LogEntry> build() {
    return [
      LogEntry(
        timestamp: DateTime.now(),
        message: 'System dashboard initialised',
        level: LogLevel.info,
      ),
    ];
  }

  void addLog(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );
    state = [entry, ...state];
    
    // Limit to last 50 logs to prevent memory bloat
    if (state.length > 50) {
      state = state.sublist(0, 50);
    }
  }
}

final systemLogProvider = NotifierProvider<SystemLogNotifier, List<LogEntry>>(() {
  return SystemLogNotifier();
});
