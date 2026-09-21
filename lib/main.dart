import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'walk_screen.dart';
import 'onboarding_view.dart';
import 'dog_date_picker.dart';
import 'dog_photo_sheet.dart';
import 'signup_view.dart';
import 'login_view.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'walk_history_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exercise_data.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'auth_routing.dart';
import 'login_screen.dart';
import 'home_screen.dart';

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
          home: const AuthGate(),
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

  // Custom SVG Icon paths extracted from Figma 
  static const String homeIconPath = 'M38.8218 39V30.44L45.0018 24.64L51.1818 30.44V39H38.8218ZM40.7218 37.1H49.2818V31.12L45.0018 27.1L40.7218 31.12V37.1Z';
  static const String exploreIconPath = 'M135.001 40.78C130.941 40.78 127.661 37.5 127.661 33.44C127.661 29.38 130.941 26.1 135.001 26.1C139.061 26.1 142.341 29.38 142.341 33.44C142.341 37.5 139.021 40.78 135.001 40.78ZM134.381 27.58C131.621 27.86 129.441 30.04 129.141 32.8H134.381V27.58ZM135.661 27.58V32.78H140.861C140.561 30.04 138.401 27.88 135.661 27.58ZM135.641 34.06V39.3C138.401 39 140.581 36.82 140.861 34.06H135.641ZM129.141 34.08C129.441 36.82 131.621 39.02 134.361 39.3V34.08H129.141Z';
  static const String rewardsIconPath = 'M225.009 39.24L217.309 31.54L224.989 23.86L232.689 31.54L225.009 39.24Z';
  static const String profileIconPath = 'M315.001 39.24C313.948 39.24 312.955 39.04 312.021 38.64C311.088 38.24 310.268 37.6933 309.561 37C308.868 36.2933 308.321 35.4733 307.921 34.54C307.521 33.6067 307.321 32.6133 307.321 31.56C307.321 30.4933 307.521 29.5 307.921 28.58C308.321 27.6467 308.868 26.8267 309.561 26.12C310.268 25.4133 311.088 24.86 312.021 24.46C312.955 24.06 313.948 23.86 315.001 23.86C316.068 23.86 317.061 24.06 317.981 24.46C318.915 24.86 319.728 25.4133 320.421 26.12C321.128 26.8267 321.681 27.6467 322.081 28.58C322.481 29.5 322.681 30.4933 322.681 31.56C322.681 32.6133 322.481 33.6067 322.081 34.54C321.681 35.4733 321.128 36.2933 320.421 37C319.728 37.6933 318.915 38.24 317.981 38.64C317.061 39.04 316.068 39.24 315.001 39.24Z';
  
  @override
  Widget build(BuildContext context) {
    // 1. Show a clean loading screen while fetching data!
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F0E9),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFDC755C)), // Coral spinner
        ),
      );
    }

    // 2. Once loaded, build the actual UI
    // List of screens for the bottom nav
    final screens = [
      // Index 0: Home
      Container(
        color: const Color(0xFFF4F0E9), // Figma background color
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (Avatar + Hi Dog Name)
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[300],
                    // Use CachedNetworkImageProvider instead of NetworkImage!
                    backgroundImage: _dogPhotoUrl != null 
                        ? CachedNetworkImageProvider(_dogPhotoUrl!) 
                        : null,
                    child: _dogPhotoUrl == null ? const Icon(Icons.pets, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Hi $_dogName!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF241C24)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Progress Rings
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Ring (KM Progress) - Blue #5F98BD
                      SizedBox(
                        width: 186,
                        height: 186,
                        child: CircularProgressIndicator(
                          value: (_currentKm / _dailyGoalKm).clamp(0.0, 1.0),
                          strokeWidth: 14,
                          color: const Color(0xFF5F98BD),
                          backgroundColor: const Color(0xFF5F98BD).withOpacity(0.2),
                        ),
                      ),
                      // Inner Ring (Minutes Progress) - Green #AEC568
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: (_currentMins / _dailyGoalMins).clamp(0.0, 1.0),
                          strokeWidth: 10,
                          color: const Color(0xFFAEC568),
                          backgroundColor: const Color(0xFFAEC568).withOpacity(0.2),
                        ),
                      ),
                      // Center Text
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // KM Section
                          Text(
                            '${_currentKm.toStringAsFixed(1)}/${_dailyGoalKm.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFF5F98BD), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFF6B5F66), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const SizedBox(height: 4), 
                          
                          // Mins Section
                          Text(
                            '$_currentMins/$_dailyGoalMins',
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFFAEC568), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const Text(
                            'MINS',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, // Changed to w800
                              color: Color(0xFF6B5F66), 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats Cards (Points & Streak)
              Row(
                children: [
                  Expanded(
                    child: _buildFigmaStatCard('Points earned', '$_totalPoints pts', Icons.star),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFigmaStatCard('Streaks', '$_dailyStreak days', Icons.local_fire_department),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Start Walk Button (Coral #DC755C)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1; // Switch to Walk tab
                    });
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text('Start walk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC755C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // View Walk History Text Button (Kept for functionality)
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WalkHistoryScreen()));
                  },
                  child: const Text('View Walk History', style: TextStyle(color: Color(0xFF6B5F66))),
                ),
              ),
            ],
          ),
        ),
      ),
      // Index 1: Walk
      const WalkScreen(),
      // Index 2: Rewards
      const RewardsScreen(),
      // Index 3: Profile
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFDAD6CD), width: 1)),
        ),
        padding: EdgeInsets.only(
          top: 8.0,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 16.0 : 8.0, 
        ),
        child: Row(
          children: [
            _buildCustomNavItem(0, 'Home', homeIconPath, '38 24 13 16'),
            _buildCustomNavItem(1, 'Explore', exploreIconPath, '127 26 16 15'),
            _buildCustomNavItem(2, 'Rewards', rewardsIconPath, '217 23 16 17'),
            _buildCustomNavItem(3, 'Profile', profileIconPath, '307 23 16 16'),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6B5F66)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF241C24))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5F66))),
        ],
      ),
    );
  }

  Widget _buildCustomNavItem(int index, String label, String iconPath, String viewBox) {
    bool isActive = _currentIndex == index;
    String hexColor = isActive ? '#0F4C81' : '#6E6A63'; // Your exact Figma colors
    
    // Construct the full SVG string dynamically
    String svgString = '''<svg viewBox="$viewBox" xmlns="http://www.w3.org/2000/svg"><path d="$iconPath" fill="$hexColor"/></svg>''';

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
            if (index == 0) _fetchHomeData();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(svgString, height: 24, width: 24),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: Color(int.parse(hexColor.replaceFirst('#', 'FF'), radix: 16)), 
                fontSize: 12
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestTile(String title, bool isDone, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: isDone ? Colors.green : Colors.grey),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 16, color: isDone ? Colors.grey : Colors.black, decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none)),
          const Spacer(),
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
        ],
      ),
    );
  }
}

// ---------------- HIGH PAW SCREEN ----------------
class HighPawScreen extends StatelessWidget {
  final String dogName;
  final int dailyGoalMins;
  final double dailyGoalKm;

  const HighPawScreen({
    super.key,
    required this.dogName,
    required this.dailyGoalMins,
    required this.dailyGoalKm,
  });

  @override
  Widget build(BuildContext context) => _screen;
}