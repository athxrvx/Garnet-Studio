import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

class UptimeService extends StateNotifier<Duration> {
  late final DateTime _startTime;
  Timer? _timer;

  UptimeService() : super(Duration.zero) {
    _startTime = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = DateTime.now().difference(_startTime);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final uptimeProvider = StateNotifierProvider<UptimeService, Duration>((ref) {
  return UptimeService();
});
