import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrap {
  // Dreamflow injects Supabase credentials via build-time dart-defines.
  // Support multiple common names to avoid "connected but missing keys" issues.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: String.fromEnvironment('SUPABASE_API_URL', defaultValue: ''),
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY_VALUE', defaultValue: String.fromEnvironment('SUPABASE_KEY', defaultValue: '')),
  );

  static bool get isConfigured => supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint('Supabase not configured (missing SUPABASE_URL / SUPABASE_ANON_KEY). Running in local demo mode.');
      return;
    }

    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      debugPrint('Supabase initialized.');
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
    }
  }

  static SupabaseClient? get client {
    if (!isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
