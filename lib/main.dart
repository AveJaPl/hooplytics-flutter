import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';
import 'services/sherpa_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initSherpa(); // no-op on web, initBindings() on iOS/Android

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0C0C0E),
    ),
  );

  runApp(const HooplyticApp());
}

class HooplyticApp extends StatelessWidget {
  const HooplyticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hooplytics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

abstract class AppColors {
  static const bg = Color(0xFF0C0C0E);
  static const surface = Color(0xFF141417);
  static const surfaceHi = Color(0xFF1C1C21);
  static const border = Color(0xFF252529);
  static const borderSub = Color(0xFF1A1A1E);
  static const gold = Color(0xFFD4A843);
  static const goldMid = Color(0xFFAA8530);
  static const goldSoft = Color(0x18D4A843);
  static const goldGlow = Color(0x30D4A843);
  static const text1 = Color(0xFFF0F0F2);
  static const text2 = Color(0xFFAAAAAF);
  static const text3 = Color(0xFF70707A);
  static const green = Color(0xFF3DD68C);
  static const greenSoft = Color(0x163DD68C);
  static const red = Color(0xFFFF5252);
  static const redSoft = Color(0x16FF5252);
  static const blue = Color(0xFF5E8FEF);
  static const blueSoft = Color(0x165E8FEF);
  static const orange = Color(0xFFFF9800);
}

abstract class AppText {
  static TextStyle display(double size, {Color color = AppColors.text1}) =>
      GoogleFonts.bebasNeue(
          fontSize: size, color: color, letterSpacing: 1.0, height: 1.0);

  static TextStyle ui(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text1,
    double letterSpacing = 0.0,
  }) =>
      GoogleFonts.dmSans(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing);
}
