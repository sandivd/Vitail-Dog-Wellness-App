import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

const String supabaseUrl = 'https://wvaivqtoriceinqzqeaf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_EsVDR5mB7Ud9ErJ_theXKA_qMwNuw4G';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const VitailApp());
}

// Global notifier for Dark Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class VitailApp extends StatelessWidget {
  const VitailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Vitail',
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans',
            colorScheme: const ColorScheme.light(
              surface: Color(0xFFF4F0E9),       // Beige background
              primary: Color(0xFFDC755C),       // Coral button
              onSurface: Color(0xFF1E1E1E),     // Dark Ink text
              onSurfaceVariant: Color(0xFF7C776E), // Muted grey text
              secondary: Color(0xFF5F98BD),     // Blue ring
              tertiary: Color(0xFFAEC568),      // Green ring
              onPrimary: Colors.white,
              outline: Color(0xFFDED2D6),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans',
            colorScheme: const ColorScheme.dark(
              surface: Color(0xFF121212),       // True dark background
              primary: Color(0xFFDC755C),       // Coral button (stays same)
              onSurface: Color(0xFFF4F0E9),     // Beige text (inverted)
              onSurfaceVariant: Color(0xFFAAAAAA), // Lighter muted grey
              secondary: Color(0xFF5F98BD),     // Blue ring
              tertiary: Color(0xFFAEC568),      // Green ring
              outline: Color(0xFF444444),
            ),
          ),
          themeMode: currentMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}