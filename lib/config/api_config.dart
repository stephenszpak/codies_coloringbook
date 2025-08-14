import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String? _cachedApiKey;

  /// Initialize the environment configuration
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      print('Warning: Could not load .env file: $e');
    }
  }

  /// Get the OpenAI API key from .env file
  static String? getOpenAIApiKey() {
    _cachedApiKey ??= dotenv.env['OPENAI_API_KEY'];
    return _cachedApiKey;
  }

  /// Validate API key format
  static bool isValidApiKey(String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return false;
    
    // OpenAI API keys start with 'sk-' and are typically 20+ characters
    return apiKey.startsWith('sk-') && apiKey.length >= 20;
  }

  /// Clear cached API key (useful for testing)
  static void clearCache() {
    _cachedApiKey = null;
  }
}