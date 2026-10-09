/// Build-time configuration, passed with --dart-define (or --dart-define-from-file=env.json).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Where password-reset and confirmation links land. For the web build this
  /// is your site URL; mobile apps use the custom scheme below.
  static const webRedirectUrl = String.fromEnvironment('WEB_REDIRECT_URL');
  static const mobileRedirectUrl = 'io.autox.app://login-callback';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
