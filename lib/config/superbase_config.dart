import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Supabase Database URL
  static const String supabaseUrl = 'https://hhbqmrtpvqdmkscagkqi.supabase.co';

  // Supabase API KEY
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhoYnFtcnRwdnFkbWtzY2Fna3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MjAwODIsImV4cCI6MjA3MTI5NjA4Mn0.nfWJ3MCf5PyVw-Bf4ztauSS9vCD7UViVLZmAg6ilkHc';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
