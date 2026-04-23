import 'package:flutter/material.dart';

/// Data model for a feature introduction item.
/// Each item represents a feature that the user can learn about.
class FeatureIntroModel {
  final String id;
  final String featureName;
  final String description;
  final IconData icon;
  final Color iconBackgroundColor;

  const FeatureIntroModel({
    required this.id,
    required this.featureName,
    required this.description,
    required this.icon,
    required this.iconBackgroundColor,
  });
}

/// Predefined list of features to introduce to new users.
/// Order matters — this is the display order.
class FeatureIntroData {
  const FeatureIntroData._();

  static const String appName = 'ChatAway+';

  static const List<FeatureIntroModel> features = [
    FeatureIntroModel(
      id: 'intro_feature',
      featureName: 'Intro Feature',
      description: 'Get started with ChatAway+ and discover what makes it special',
      icon: Icons.rocket_launch_rounded,
      iconBackgroundColor: Color(0xFF6366F1), // Indigo
    ),
    FeatureIntroModel(
      id: 'express_hub',
      featureName: 'Express Hub',
      description: 'Share voice texts and emoji updates with your contacts',
      icon: Icons.campaign_rounded,
      iconBackgroundColor: Color(0xFFEC4899), // Pink
    ),
    FeatureIntroModel(
      id: 'follow_ups',
      featureName: 'Follow Ups',
      description: 'Never miss important messages — mark and track follow-ups',
      icon: Icons.flag_rounded,
      iconBackgroundColor: Color(0xFFF59E0B), // Amber
    ),
    FeatureIntroModel(
      id: 'likes_hub',
      featureName: 'Likes Hub',
      description: 'See who liked your profile picture and engage with connections',
      icon: Icons.favorite_rounded,
      iconBackgroundColor: Color(0xFFEF4444), // Red
    ),
    FeatureIntroModel(
      id: 'mood_your_way',
      featureName: 'Mood Your Way',
      description: 'Set your current mood emoji with a timer — only you can see it',
      icon: Icons.mood_rounded,
      iconBackgroundColor: Color(0xFF10B981), // Emerald
    ),
  ];
}
