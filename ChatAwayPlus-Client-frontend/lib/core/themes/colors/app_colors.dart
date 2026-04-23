import 'package:flutter/material.dart';

/// ChatAway+ App Color Palette
/// Organized by category for easy reference and maintenance
class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY COLORS - Main brand identity (Blue)
  // ═══════════════════════════════════════════════════════════════════════════

  // ACTIVE: Tailwind Sky 500 - Modern, energetic, vibrant (2024/2025 trend)
  static const Color primary = Color(
    0xFF0EA5E9,
  ); // Tailwind Sky 500 - Battle-tested by millions
  static const Color primaryLight = Color(
    0xFF38BDF8,
  ); // Tailwind Sky 400 - Lighter variant
  static const Color primaryDark = Color(
    0xFF0284C7,
  ); // Tailwind Sky 600 - Darker variant

  // Chat bubble colors
  static const Color senderBubble = Color(
    0xFFE0F2FE,
  ); // Tailwind Sky 100 - Light blue for sender messages
  static const Color receiverBubble = Color(
    0xFFFFFFFF,
  ); // Pure white for receiver messages

  static const Gradient sunsetGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFFEC4899), Color(0xFFA855F7), Color(0xFF6366F1)],
  );

  static const Gradient copperSunsetGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFFE11D48)],
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCIAL & SPECIAL COLORS - Stories, status indicators
  // ═══════════════════════════════════════════════════════════════════════════

  // Legacy gradient kept for future reuse/reference
  static const LinearGradient storiesNorthernLights = LinearGradient(
    colors: [
      Color(0xFF2DD4BF), // from-teal-400
      Color(0xFF3B82F6), // via-blue-500
      Color(0xFF7C3AED), // to-purple-600
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Morning Sky gradient (kept for quick toggles)
  static const LinearGradient storiesMorningSky = LinearGradient(
    colors: [
      Color(0xFFBFDBFE), // from-blue-200
      Color(0xFF93C5FD), // via-blue-300
      Color(0xFF60A5FA), // to-blue-400
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Active Cotton Candy Sky gradient (pink→purple→blue)
  static const LinearGradient storiesCottonCandySky = LinearGradient(
    colors: [
      Color(0xFFF9A8D4), // from-pink-300
      Color(0xFFD8B4FE), // via-purple-200
      Color(0xFF93C5FD), // to-blue-300
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Deep Sky gradient (blue-400 → blue-600)
  static const LinearGradient storiesDeepSky = LinearGradient(
    colors: [
      Color(0xFF60A5FA), // from-blue-400
      Color(0xFF2563EB), // to-blue-600
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Lagoon gradient (emerald → teal → blue)
  static const LinearGradient storiesLagoon = LinearGradient(
    colors: [
      Color(0xFF34D399), // from-emerald-400
      Color(0xFF2DD4BF), // via-teal-400
      Color(0xFF60A5FA), // to-blue-400
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Bali Sunrise gradient (orange → pink → purple)
  static const LinearGradient storiesBaliSunrise = LinearGradient(
    colors: [
      Color(0xFFF97316), // from-orange-400
      Color(0xFFF472B6), // via-pink-400
      Color(0xFFA855F7), // to-purple-500
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Paris Evening gradient (blue → purple → pink)
  static const LinearGradient storiesParisEvening = LinearGradient(
    colors: [
      Color(0xFF2563EB), // from-blue-600
      Color(0xFFA78BFA), // via-purple-400
      Color(0xFFF9A8D4), // to-pink-300
    ],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // ALTERNATIVE OPTIONS (commented for future use):
  // static const Color primary = Color(0xFF218AFF); // iMessage Blue - Premium, trusted, familiar
  // static const Color primary = Color(0xFF3390EC); // Telegram Blue - Vibrant, modern, proven
  // static const Color primary = Color(0xFF82C8E5); // Figma Sky Blue - Bright & energizing
  // static const Color primary = Color(0xFF0088CC); // Telegram Official - Clean & professional

  // ═══════════════════════════════════════════════════════════════════════════
  // GREY SCALE - Icons, text, borders, dividers
  // ═══════════════════════════════════════════════════════════════════════════

  // Icon colors (mapped to grey scale)
  static const Color iconPrimary = Color(0xFF212121); // Dark icons
  static const Color iconSecondary = Color(0xFF757575); // Secondary icons
  static const Color lighterGrey = Color(0xFFE0E0E0); // Subtle UI elements

  // Grey shades for theme
  static const Color greyLightest = Color(
    0xFFF5F5F5,
  ); // Very light grey backgrounds
  static const Color greyLight = Color(
    0xFFE0E0E0,
  ); // Light grey borders, dividers
  static const Color greyBackground = Color(0xFFF7F9FB);
  static const Color greyMedium = Color(0xFF9E9E9E); // Medium grey
  static const Color greyDark = Color(0xFF616161); // Dark grey

  // Text colors
  static const Color greyTextPrimary = Color(0xFF212121); // Primary text
  static const Color greyTextSecondary = Color(0xFF757575); // Secondary text

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY COLORS - Backward compatibility (avoid using in new code)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color colorBlack = Color(0xFF000000);
  static const Color colorWhite = Color(0xFFFFFFFF);
  static const Color colorGrey = Color(0xFF616161);

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS - Success, error, warning indicators
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color error = Color(0xFFE53935); // Red
  static const Color warning = Color(0xFFFFB300); // Amber
  static const Color info = Color(0xFF2196F3); // Blue

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION & BADGE COLORS - Unread message count badges
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color badgeRed = Color(
    0xFFFF3B30,
  ); // iOS Red - Unread count (WhatsApp/Messenger style)
  static const Color badgeBackground =
      badgeRed; // Main badge color for unread messages
  static const Color badgeText = Color(0xFFFFFFFF); // White text on red badge

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCIAL & SPECIAL COLORS - Stories, status indicators
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color activeStatus = primary; // Online status
  static const Color inactiveStatus = Color(0xFFBDBDBD); // Offline status

  // ═══════════════════════════════════════════════════════════════════════════
  // MATERIAL 3 COLOR SCHEME
  // ═══════════════════════════════════════════════════════════════════════════
  static ColorScheme get lightColorScheme => ColorScheme.light(
    primary: primary,

    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: iconPrimary,
    onError: Colors.white,
  );
}
