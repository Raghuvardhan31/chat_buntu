import 'package:flutter/material.dart';
import 'package:chataway_plus/core/constants/assets/image_assets.dart';

class ChatBackgroundWidget extends StatelessWidget {
  const ChatBackgroundWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        if (isDark) ...[
          // Base dark background (WhatsApp dark color)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0B141A), // WhatsApp dark background
            ),
          ),
          // Doodle pattern visible in dark mode (like WhatsApp)
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(ImageAssets.chatBackground, fit: BoxFit.cover),
            ),
          ),
        ] else ...[
          // Light mode: pattern first, then overlay
          Positioned.fill(
            child: Image.asset(ImageAssets.chatBackground, fit: BoxFit.cover),
          ),
          // White overlay (68% opacity) - WhatsApp-style visible pattern
          Positioned.fill(
            child: Container(
              color: const Color(0xADFFFFFF), // Light mode: 68% white
            ),
          ),
          // Sky 100 tint (7% opacity) - matches sender bubble for color harmony
          Positioned.fill(
            child: Container(
              color: const Color(0x12E0F2FE), // ARGB: 7% Sky 100 (#E0F2FE)
            ),
          ),
          // Subtle gradient sheen for style
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x10FFFFFF), // ~6% white at top
                    Color(0x00FFFFFF), // transparent mid
                    Color(0x0DFFFFFF), // ~5% white at bottom
                  ],
                  stops: <double>[0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
