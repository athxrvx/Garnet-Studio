import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/settings_service.dart';

class NavSidebar extends ConsumerWidget {
  const NavSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final userNameAsync = ref.watch(userNameProvider);
    final isHovered = false; // TODO: Add hover effect logic if needed

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppConstants.sidebarBackgroundColor,
        border: Border(right: BorderSide(color: AppConstants.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Logo
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Logo Icon
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Image.asset('assets/app_logo.png', fit: BoxFit.contain)
                ),
                const SizedBox(width: 12),
                const Text(
                  'GARNET STUDIO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppConstants.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const _NavSection(title: 'MAIN'),
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Overview',
                  isSelected: currentIndex == 0,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.smartphone_outlined,
                  label: 'Devices',
                  isSelected: currentIndex == 1,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Models',
                  isSelected: currentIndex == 2,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = 2,
                ),
                _NavItem(
                  icon: Icons.travel_explore, // Research
                  label: 'Research Engine',
                  isSelected: currentIndex == 3,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = 3,
                ),
                
                const SizedBox(height: 24),
                const _NavSection(title: 'CONSOLE'),
                _NavItem(
                  icon: Icons.terminal, // Terminal style icon
                  label: 'Chat Console',
                  isSelected: currentIndex == 4,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = 4,
                ),

                const SizedBox(height: 24),
                const _NavSection(title: 'SYSTEM'),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isSelected: currentIndex == 5,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = 5,
                ),
              ],
            ),
          ),
          
          // User Profile / Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppConstants.surfaceColorAlt,
                  child: const Icon(Icons.person, size: 14, color: AppConstants.textSecondary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userNameAsync.valueOrNull ?? 'User', 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)
                    ),
                    Text(
                      Platform.localHostname, 
                      style: const TextStyle(fontSize: 10, color: AppConstants.textTertiary)
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String title;
  const _NavSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: AppConstants.surfaceColorAlt,
          child: AnimatedContainer(
             duration: const Duration(milliseconds: 200),
             decoration: BoxDecoration(
               color: isSelected 
                   ? theme.colorScheme.primary.withOpacity(0.15) 
                   : Colors.transparent,
               border: Border(
                 left: BorderSide(
                   color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                   width: 3,
                 ),
               ),
             ),
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
             child: Row(
               children: [
                 Icon(
                   icon, 
                   size: 20, 
                   color: isSelected ? theme.colorScheme.primary : AppConstants.textSecondary
                 ),
                 const SizedBox(width: 12),
                 Text(
                   label,
                   style: TextStyle(
                     fontSize: 13,
                     color: isSelected ? AppConstants.textPrimary : AppConstants.textSecondary,
                     fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                   ),
                 ),
               ],
             ),
          ),
        ),
      ),
    );
  }
}
