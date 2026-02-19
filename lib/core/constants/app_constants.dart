import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Garnet Studio';
  static const String appVersion = '1.0.0';
  
  // Server defaults
  static const int defaultServerPort = 8787;
  static const String serviceType = '_garnet._tcp';
  static const String serviceHostname = 'garnet-studio.local';
  
  // Ollama defaults
  static const String ollamaBaseUrl = 'http://127.0.0.1:11434';
  
  // UI dimensions
  static const double sidebarWidth = 260.0;
  static const double borderRadius = 12.0;

  // Colors
  static const Color accentColor = Color(0xFFF50F44); // Primary Red/Pink
  
  // Backgrounds
  static const Color scaffoldBackgroundColor = Color(0xFF121212); // Deep Dark, not pure black
  static const Color sidebarBackgroundColor = Color(0xFF1A1A1A); // Slightly lighter
  static const Color surfaceColor = Color(0xFF222222); // Cards, Dialogs
  static const Color surfaceColorAlt = Color(0xFF2C2C2C); // Hover states etc.

  // Legacy/Alias Support (Mapped to new system for compatibility)
  static const Color darkBackground = scaffoldBackgroundColor;
  static const Color sidebarBackground = sidebarBackgroundColor;
  static const Color lighterBackground = surfaceColorAlt;
  
  // Text
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF666666);

  // Status
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFCF6679);

  // Borders
  static Color borderColor = const Color(0xFFFFFFFF).withOpacity(0.08);

  // Storage keys
  static const String authorizedDevicesKey = 'authorized_devices';
  static const String chatHistoryKey = 'chat_history';
}
