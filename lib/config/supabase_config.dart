/// Supabase configuration.
/// Replace these placeholders with your actual Supabase project credentials.
class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Google OAuth Client ID (for Google Sign-In)
  // Web client ID from Google Cloud Console
  static const String googleWebClientId = 'YOUR_GOOGLE_WEB_CLIENT_ID';

  // iOS client ID (from GoogleService-Info.plist)
  static const String googleIosClientId = 'YOUR_GOOGLE_IOS_CLIENT_ID';
}
