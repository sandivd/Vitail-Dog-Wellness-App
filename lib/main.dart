import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_routing.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

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
              surface: Color(0xFFF4F0E9),
              primary: Color(0xFFDC755C),
              onSurface: Color(0xFF1E1E1E),
              onSurfaceVariant: Color(0xFF7C776E),
              secondary: Color(0xFF5F98BD),
              tertiary: Color(0xFFAEC568),
              onPrimary: Colors.white,
              outline: Color(0xFFDED2D6),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: 'PlusJakartaSans',
            colorScheme: const ColorScheme.dark(
              surface: Color(0xFF121212),
              primary: Color(0xFFDC755C),
              onSurface: Color(0xFFF4F0E9),
              onSurfaceVariant: Color(0xFFAAAAAA),
              secondary: Color(0xFF5F98BD),
              tertiary: Color(0xFFAEC568),
              outline: Color(0xFF444444),
            ),
          ),
          themeMode: currentMode,
          home: const OnboardingScreen(),
        );
      },
    );
  }
}

/// Restores the session on cold start. `auth.initialSession` resolves
/// exactly once with the persisted session (or null) — no more always
/// landing on the login screen for returning users.
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