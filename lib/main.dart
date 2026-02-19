import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/constants/app_constants.dart';
import 'core/root_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: AppConstants.appName,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // Forcefully hide title bar for custom implementation
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    // Attempt to set icon programmatically (this requires the file to be available to the OS)
    // Note: For production, prefer setting the .ico in windows/runner/resources/
    // await windowManager.setIcon('assets/app_logo.png'); 
    await windowManager.setPreventClose(true); // Optional: handle close request manually if needed
  });

  runApp(
    const ProviderScope(
      child: GarnetStudioApp(),
    ),
  );
}

class GarnetStudioApp extends StatelessWidget {
  const GarnetStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppConstants.scaffoldBackgroundColor,
        colorScheme: ColorScheme.dark(
          primary: AppConstants.accentColor,
          surface: AppConstants.surfaceColor, // Sidebar/Panels
          onSurface: AppConstants.textPrimary,
          background: AppConstants.scaffoldBackgroundColor,
        ),
        visualDensity: VisualDensity.standard,
        fontFamily: 'Segoe UI Variable Display',
        cardTheme: CardThemeData(
          color: AppConstants.surfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(color: AppConstants.borderColor),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius + 4),
            side: BorderSide(color: AppConstants.borderColor, width: 1),
          ),
        ),
      ),
      home: const AppRoot(),
    );
  }
}

