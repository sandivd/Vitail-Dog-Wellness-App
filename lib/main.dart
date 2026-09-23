import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_routing.dart';
import 'home_screen.dart';
import 'login_screen.dart';

const String supabaseUrl = 'https://wvaivqtoriceinqzqeaf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_EsVDR5mB7Ud9ErJ_theXKA_qMwNuw4G';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  // Restore the saved theme before the first frame (Settings persists it).
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value =
      (prefs.getBool('darkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;

  runApp(const VitailApp());
}

// Global notifier for Dark Mode
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Built ONCE at first use. (Defining these inside the ValueListenableBuilder
// re-created BOTH themes on every Dark Mode toggle — ThemeData() is expensive.)
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'PlusJakartaSans',
  colorScheme: const ColorScheme.light(
    surface: Color(0xFFF4F0E9),          // Beige background
    primary: Color(0xFFDC755C),          // Coral button
    onSurface: Color(0xFF1E1E1E),        // Dark Ink text
    onSurfaceVariant: Color(0xFF7C776E), // Muted grey text
    secondary: Color(0xFF5F98BD),        // Blue ring
    tertiary: Color(0xFFAEC568),         // Green ring
    onPrimary: Colors.white,
    outline: Color(0xFFDED2D6),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'PlusJakartaSans',
  colorScheme: const ColorScheme.dark(
    surface: Color(0xFF121212),          // True dark background
    primary: Color(0xFFDC755C),          // Coral button (stays same)
    onSurface: Color(0xFFF4F0E9),        // Beige text (inverted)
    onSurfaceVariant: Color(0xFFAAAAAA), // Lighter muted grey
    secondary: Color(0xFF5F98BD),        // Blue ring
    tertiary: Color(0xFFAEC568),         // Green ring
    outline: Color(0xFF444444),
  ),
);

class VitailApp extends StatelessWidget {
  const VitailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Vitail',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: currentMode,
          // Default is 200ms / linear, which reads as laggy.
          // 150ms / easeOut feels snappy. (Duration.zero = instant swap.)
          themeAnimationDuration: const Duration(milliseconds: 150),
          themeAnimationCurve: Curves.easeOut,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Restores the session on cold start so returning users skip the login
/// screen, then routes to onboarding or home depending on whether they've
/// added a dog yet.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget _screen = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final client = Supabase.instance.client;

    // Session restore is asynchronous. Depending on the supabase_flutter
    // version, either `currentSession` is already populated right after
    // `await Supabase.initialize()`, or we pick the session up from the
    // first event on the auth stream — which always fires on subscribe,
    // carrying the restored session (or null if signed out).
    final session = client.auth.currentSession ??
        (await client.auth.onAuthStateChange.first).session;

    if (!mounted) return;

    if (session == null) {
      setState(() => _screen = const LoginScreen());
      return;
    }

    Widget destination;
    try {
      destination = await resolvePostAuthScreen();
    } catch (_) {
      // Signed in, but the dog lookup failed (e.g. a network hiccup).
      // HomeScreen degrades gracefully without a dog row, so prefer that
      // over leaving the user on a spinner forever.
      destination = const HomeScreen();
    }

    if (mounted) setState(() => _screen = destination);
  }

  @override
  Widget build(BuildContext context) => _screen;
}