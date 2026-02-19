import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_service.dart';
import '../features/layout/main_layout.dart';
import '../features/onboarding/onboarding_view.dart';
import 'constants/app_constants.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingStatusProvider);

    return onboardingAsync.when(
      data: (isComplete) {
        if (isComplete) {
          return const MainLayout();
        } else {
          return const OnboardingView();
        }
      },
      loading: () => const Scaffold(
        backgroundColor: AppConstants.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppConstants.accentColor),
        ),
      ),
      error: (e, stack) => Scaffold(
        body: Center(
          child: Text("Error loading app: $e"),
        ),
      ),
    );
  }
}
