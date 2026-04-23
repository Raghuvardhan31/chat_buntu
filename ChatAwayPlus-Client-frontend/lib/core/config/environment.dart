// ============================================================================
// ENVIRONMENT CONFIGURATION - Dev/Staging/Production
// ============================================================================
// Manages different environments for safe testing and deployment.
//
// WHY CRITICAL:
// - Test features without affecting production users
// - Different API servers for dev/staging/prod
// - Different Firebase projects
// - Debug settings only in development
//
// USAGE:
//   // In main.dart, set environment first:
//   Environment.init(EnvironmentType.development);
//   
//   // Then access anywhere in app:
//   final apiUrl = Environment.apiBaseUrl;
//   final isDebug = Environment.isDebug;
//
// ============================================================================

enum EnvironmentType {
  development,  // For local development
  staging,      // For testing with QA team
  production,   // For real users (Google Play)
}

class Environment {
  static EnvironmentType _currentEnvironment = EnvironmentType.development;
  
  /// Initialize environment (call in main.dart before runApp)
  static void init(EnvironmentType environment) {
    _currentEnvironment = environment;
    print('🌍 Environment: ${environment.name.toUpperCase()}');
    print('📡 API Base URL: $apiBaseUrl');
    print('🔥 Firebase Project: $firebaseProjectId');
  }
  
  /// Current environment
  static EnvironmentType get current => _currentEnvironment;
  
  // =========================================================================
  // ENVIRONMENT-SPECIFIC SETTINGS
  // =========================================================================
  
  /// API Base URL (changes per environment)
  static String get apiBaseUrl {
    switch (_currentEnvironment) {
      case EnvironmentType.development:
        return 'https://dev-api.chatawayplus.com';  // Your dev server
      case EnvironmentType.staging:
        return 'https://staging-api.chatawayplus.com';  // QA testing
      case EnvironmentType.production:
        return 'https://api.chatawayplus.com';  // Production server
    }
  }
  
  /// Firebase Project ID
  static String get firebaseProjectId {
    switch (_currentEnvironment) {
      case EnvironmentType.development:
        return 'chataway-dev';
      case EnvironmentType.staging:
        return 'chataway-staging';
      case EnvironmentType.production:
        return 'chataway-prod';
    }
  }
  
  /// Enable debug logging
  static bool get isDebug {
    return _currentEnvironment != EnvironmentType.production;
  }
  
  /// Enable verbose API logging
  static bool get enableApiLogging {
    return _currentEnvironment == EnvironmentType.development;
  }
  
  /// Database name (different per environment)
  static String get databaseName {
    switch (_currentEnvironment) {
      case EnvironmentType.development:
        return 'chataway_dev.db';
      case EnvironmentType.staging:
        return 'chataway_staging.db';
      case EnvironmentType.production:
        return 'chataway.db';
    }
  }
  
  /// Show debug UI elements (like test buttons)
  static bool get showDebugUI {
    return _currentEnvironment == EnvironmentType.development;
  }
  
  /// Timeout for API calls (longer in dev for debugging)
  static Duration get apiTimeout {
    return _currentEnvironment == EnvironmentType.development
        ? Duration(seconds: 60)  // Longer for debugging
        : Duration(seconds: 30);
  }
  
  // =========================================================================
  // FEATURE FLAGS (Enable/disable features per environment)
  // =========================================================================
  
  /// Enable auto-response testing in chat
  static bool get enableAutoResponseTesting {
    return _currentEnvironment == EnvironmentType.development;
  }
  
  /// Enable analytics
  static bool get enableAnalytics {
    return _currentEnvironment == EnvironmentType.production;
  }
  
  /// Enable crash reporting
  static bool get enableCrashReporting {
    return _currentEnvironment != EnvironmentType.development;
  }
}
