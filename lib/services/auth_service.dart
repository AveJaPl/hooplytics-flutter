import 'dart:ui';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'base_service.dart';

/// Authentication service wrapping Supabase Auth.
/// Handles email/password, Google, and Apple sign-in.
class AuthService extends BaseService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // ─── Current user ───────────────────────────────
  User? get currentUser => client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Stream of auth state changes for reactive routing.
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ─── Email / Password ──────────────────────────
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  // ─── Google Sign-In ─────────────────────────────
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      clientId: SupabaseConfig.googleIosClientId,
      serverClientId: SupabaseConfig.googleWebClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Logowanie Google anulowane.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw const AuthException('Brak tokenu Google ID.');
    }

    return await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // ─── Apple Sign-In ──────────────────────────────
  Future<bool> signInWithApple() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.hooplytics://login-callback/',
    );
  }

  // ─── Password Reset ─────────────────────────────
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // ─── Sign Out ───────────────────────────────────
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Updates current user's metadata (e.g. display_name).
  Future<UserResponse> updateUserMetadata(Map<String, dynamic> data) async {
    return await client.auth.updateUser(
      UserAttributes(data: data),
    );
  }
}

// ─── Password Strength Utility ─────────────────────
enum PasswordStrengthLevel { none, weak, fair, strong, veryStrong }

class PasswordStrength {
  final PasswordStrengthLevel level;
  final int score; // 0-4

  const PasswordStrength({required this.level, required this.score});

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
          level: PasswordStrengthLevel.none, score: 0);
    }

    int score = 0;

    // Length checks
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;

    // Complexity checks
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:,\.<>\?/\\|`~]')
        .hasMatch(password)) {
      score++;
    }

    // Cap at 4
    score = score.clamp(0, 4);

    final level = switch (score) {
      0 => PasswordStrengthLevel.none,
      1 => PasswordStrengthLevel.weak,
      2 => PasswordStrengthLevel.fair,
      3 => PasswordStrengthLevel.strong,
      _ => PasswordStrengthLevel.veryStrong,
    };

    return PasswordStrength(level: level, score: score);
  }

  String get label => switch (level) {
        PasswordStrengthLevel.none => '',
        PasswordStrengthLevel.weak => 'Słabe',
        PasswordStrengthLevel.fair => 'Średnie',
        PasswordStrengthLevel.strong => 'Silne',
        PasswordStrengthLevel.veryStrong => 'Bardzo silne',
      };

  Color get color => switch (level) {
        PasswordStrengthLevel.none => const Color(0xFF444444),
        PasswordStrengthLevel.weak => const Color(0xFFFF3B3B),
        PasswordStrengthLevel.fair => const Color(0xFFFFAA00),
        PasswordStrengthLevel.strong => const Color(0xFF4CAF50),
        PasswordStrengthLevel.veryStrong => const Color(0xFF00E676),
      };
}
