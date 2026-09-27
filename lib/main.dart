import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_routing.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';
import 'vitail_launch.dart';
import 'notifications.dart';

const String supabaseUrl = 'https://wvaivqtoriceinqzqeaf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_EsVDR5mB7Ud9ErJ_theXKA_qMwNuw4G';

/// Cached in main() so any screen can read preferences synchronously —
/// no first-frame flash of default values (the async-load gap that made
/// the walk-reminders switch visibly animate off on open).
late final SharedPreferences appPrefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  appPrefs = await SharedPreferences.getInstance();
  themeNotifier.value =
      (appPrefs.getBool('darkMode') ?? false) ? ThemeMode.dark : ThemeMode.light;

  await Notifications.init();
  runApp(const VitailApp());

  // Restore the daily reminder if it's on (covers reinstalls/updates;
  // device reboots are handled by the manifest boot receiver).
  unawaited(() async {
    if (appPrefs.getBool('walkReminders') ?? false) {
      final client = Supabase.instance.client;

      // The session restores asynchronously — wait for it (same pattern
      // as AuthGate) so the reminder message can use the dog's name,
      // goal and streak. Skip entirely if signed out; the previously
      // scheduled alarm just keeps its last message.
      if (client.auth.currentSession == null) {
        await client.auth.onAuthStateChange.first;
      }
      if (client.auth.currentUser == null) return;

      await Notifications.scheduleWalkReminder(
        hour: appPrefs.getInt('reminderHour') ?? 9,
        minute: appPrefs.getInt('reminderMinute') ?? 0,
      );
    }
  }());
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

/// Lets us navigate from places with no BuildContext under the MaterialApp
/// (the password-recovery listener below).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class VitailApp extends StatefulWidget {
  const VitailApp({super.key});

  @override
  State<VitailApp> createState() => _VitailAppState();
}

class _VitailAppState extends State<VitailApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    // When the user taps the reset link in their email, the OS opens the
    // app, supabase_flutter exchanges the recovery code for a session, and
    // this event fires. Listening at the app root (not on any one screen)
    // means it works regardless of which screen is showing — including
    // cold starts, which race AuthGate's own boot logic.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          title: 'Vitail',
          navigatorKey: navigatorKey,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: currentMode,
          themeAnimationDuration: const Duration(milliseconds: 150),
          themeAnimationCurve: Curves.easeOut,
          home: const VitailLaunch(child: AuthGate()),        );
      },
    );
  }
}