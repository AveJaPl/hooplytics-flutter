import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';

/// Routes users based on their Supabase auth state.
/// Logged in → Dashboard, logged out → AuthScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final session = snapshot.data!.session;

        if (session != null) {
          return const DashboardScreen();
        }

        return const AuthScreen();
      },
    );
  }
}
