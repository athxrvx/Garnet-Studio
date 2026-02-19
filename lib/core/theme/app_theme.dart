import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppConstants.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.accentColor,
        secondary: AppConstants.accentColor,
        surface: AppConstants.lighterBackground,
        background: AppConstants.darkBackground,
        error: Color(0xFFCF6679),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(
        color: Colors.white70,
        size: 20,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.1),
        thickness: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppConstants.sidebarBackground,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.sidebarBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          borderSide: const BorderSide(color: AppConstants.accentColor, width: 1.5),
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
