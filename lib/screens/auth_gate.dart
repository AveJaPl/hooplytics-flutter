import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
        // While waiting for first auth event, show loading
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B1A),
              ),
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
