import 'package:flutter/material.dart';

// Custom color palette using #A4193D and #FFDFB9
class CustomColors {
  // Primary colors
  static const Color primaryRed = Color(0xFFA4193D);
  static const Color primaryPeach = Color(0xFFFFDFB9);

  // Light mode colors
  static const Color lightBackground = Color(0xFFFFF8F3);
  static const Color lightSurface = Color(0xFFFFF8F3);
  static const Color lightOnSurface = Color(0xFF2D1B1B);
  static const Color lightOnPrimary = Color(0xFFFFF8F3);
  static const Color lightOutline = Color(0xFFD4A574);
  static const Color lightError = Color(0xFFD32F2F);
  static const Color lightSuccess = Color(0xFF388E3C);
  static const Color lightWarning = Color(0xFFF57C00);

  // Dark mode colors
  static const Color darkBackground = Color(0xFF1A0F0F);
  static const Color darkSurface = Color(0xFF2D1B1B);
  static const Color darkOnSurface = Color(0xFFFFF8F3);
  static const Color darkOnPrimary = Color(0xFF1A0F0F);
  static const Color darkOutline = Color(0xFF8B6B4A);
  static const Color darkError = Color(0xFFEF5350);
  static const Color darkSuccess = Color(0xFF81C784);
  static const Color darkWarning = Color(0xFFFFB74D);

  // Step colors using the new palette
  static const Color stepCenter = Color(0xFFA4193D);
  static const Color stepUp = Color(0xFFB84A5A);
  static const Color stepDown = Color(0xFFCC7B7B);
  static const Color stepLeft = Color(0xFFE0AC9C);
  static const Color stepRight = Color(0xFFF4DDCD);
  static const Color stepBlink = Color(0xFFFFDFB9);
  static const Color stepSmile = Color(0xFFF4DDCD);
  static const Color stepNeutral = Color(0xFFE0AC9C);

  // Helper method to get theme-appropriate colors
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryRed
        : primaryRed;
  }

  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primaryPeach
        : primaryPeach;
  }

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color getOnSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkOnSurface
        : lightOnSurface;
  }

  static Color getSuccessColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSuccess
        : lightSuccess;
  }

  static Color getErrorColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkError
        : lightError;
  }

  static Color getWarningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkWarning
        : lightWarning;
  }

  static Color getOnPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkOnPrimary
        : lightOnPrimary;
  }
}
