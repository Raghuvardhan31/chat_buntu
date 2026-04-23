// lib/features/profile/presentation/providers/index.dart

/// Profile Providers - Barrel Export File
///
/// This file has been refactored into 3 separate files following
/// the same clean architecture pattern as Chat Providers:
///
/// 1. profile_page_state.dart    - State models and enums
/// 2. profile_page_notifier.dart - Business logic and state management
/// 3. profile_page_providers.dart - Riverpod provider setup
///
/// All exports are maintained for backward compatibility.
library;

export 'profile_page_state.dart';
export 'profile_page_notifier.dart';
export 'profile_page_providers.dart';
