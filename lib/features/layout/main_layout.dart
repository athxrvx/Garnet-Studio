import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart'; // Import window_manager
import '../../core/constants/app_constants.dart';
import '../../core/providers/navigation_provider.dart';
import 'nav_sidebar.dart';
import 'status_panel.dart';
import '../dashboard/overview_view.dart';
import '../chat/chat_view.dart';
import '../devices/devices_view.dart';
import '../models/models_view.dart';
import '../research/views/research_screen.dart'; // Import ResearchScreen
import '../settings/settings_view.dart'; // Import SettingsView
import 'top_bar.dart'; // Keep for now, but we will inline it or change it

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(currentAppViewProvider);

    return Scaffold(
      backgroundColor: AppConstants.scaffoldBackgroundColor, // Main background
      body: Stack(
        children: [
          // Main Content Layer
          Column(
            children: [
               Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Sidebar (Fixed) - Extends to top
                    const NavSidebar(),
                    
                    // Center Content (Dynamic)
                    Expanded(
                      child: Container(
                        // No top padding - content goes to edge
                        color: AppConstants.scaffoldBackgroundColor, 
                        child: Column(
                          children: [
                            // Spacer for the window controls area so content doesn't get hidden behind them
                            // But background color flows through
                            const SizedBox(height: 32),
                            Expanded(child: _buildView(currentView)),
                          ],
                        ),
                      ),
                    ),
                    
                    // Right Status Panel (Fixed)
                    // Removed top padding so the background color extends to the window edge
                    const StatusPanel(),
                  ],
                ),
              ),
            ],
          ),

          // Window Controls Layer (Floating on top)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 32, // Height of the title bar area
            child: TopBar(), 
          ),
        ],
      ),
    );
  }

  Widget _buildView(AppView view) {
    switch (view) {
      case AppView.overview:
        return const OverviewView();
      case AppView.devices:
        return const DevicesView();
      case AppView.models:
        return const ModelsView();
      case AppView.research:
        return const ResearchScreen();
      case AppView.chat:
        return const ChatView();
      case AppView.settings:
        return const SettingsView();
    }
  }
}
