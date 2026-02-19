import 'package:flutter_riverpod/flutter_riverpod.dart';

// Represents the current active view index
final navigationIndexProvider = StateProvider<int>((ref) => 0);

enum AppView {
  overview,
  devices,
  models,
  research,
  chat,
  settings
}

final currentAppViewProvider = Provider<AppView>((ref) {
  final index = ref.watch(navigationIndexProvider);
  return AppView.values[index];
});