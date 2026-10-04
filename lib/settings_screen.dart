import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'main.dart';
import 'notifications.dart';
import 'vitail_snack.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  int _reminderHour = 9;
  int _reminderMinute = 0;
  bool _isSigningOut = false;
  bool _isExporting = false;
  bool _isDeleting = false;

  // ---- Design tokens (Figma "Settings"); dark values derive from the app theme.
  Color get background => Theme.of(context).colorScheme.surface;
  Color get ink => Theme.of(context).colorScheme.onSurface;
  Color get muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get border => Theme.of(context).colorScheme.outline;
  Color get coral => Theme.of(context).colorScheme.primary;
  Color get cardFill => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  static const _cardRadius = 17.5;

  TextStyle style(double size,
          {Color? color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: size,
          fontWeight: weight,
          color: color ?? ink);


  @override
  void initState() {
    super.initState();
    // appPrefs is cached in main(), so these reads are synchronous —
    // correct values on the first frame, no toggle flash.
    _notificationsEnabled = appPrefs.getBool('walkReminders') ?? false;
    _reminderHour = appPrefs.getInt('reminderHour') ?? 9;
    _reminderMinute = appPrefs.getInt('reminderMinute') ?? 0;
  }

  // ------------------------------------------------------------- preferences

  Future<void> _setDarkMode(bool dark) async {
    // No setState needed: the app-level theme change already rebuilds this
    // screen (its colour getters all read Theme.of(context)).
    themeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', dark);
  }

  // NEW: persist the walk-reminders toggle so it survives sign-out/in
  // and app restarts (local device preference, like dark mode).
  Future<void> _setWalkReminders(bool enabled) async {
    if (enabled) {
      final granted = await Notifications.requestPermission();
      if (!granted) {
        if (!mounted) return;
        showVitailSnack(
          context,
          'Vitail needs notification permission for walk reminders. '
              'Enable it in system settings, then try again.',
          type: VitailSnackType.info,
        );
        return; // no setState — the switch stays off
      }
      await Notifications.scheduleWalkReminder(
          hour: _reminderHour, minute: _reminderMinute);
    } else {
      await Notifications.cancelWalkReminder();
    }
    setState(() => _notificationsEnabled = enabled);
    await appPrefs.setBool('walkReminders', enabled);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    await appPrefs.setInt('reminderHour', _reminderHour);
    await appPrefs.setInt('reminderMinute', _reminderMinute);

    if (_notificationsEnabled) {
      // Cancel-then-schedule with a fixed ID: re-scheduling is idempotent.
      await Notifications.scheduleWalkReminder(
          hour: _reminderHour, minute: _reminderMinute);
    }
  }

  Future<void> _openEditProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final dog = await Supabase.instance.client
          .from('dogs')
          .select()
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      if (dog == null) {
        showVitailSnack(context, 'No dog profile found yet.',
            type: VitailSnackType.info);
        return;
      }
      await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (context) => EditProfileScreen(dog: dog)));
    } catch (_) {
      if (mounted) {
        showVitailSnack(context, 'Could not load dog profile.',
            type: VitailSnackType.error);
      }
    }
  }

  // ------------------------------------------------------------------ export

  Future<void> _exportData() async {
    if (_isExporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isExporting = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not signed in');

      // RLS scopes every query below to this user's own rows, so the whole
      // export can run client-side — no server endpoint needed.
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      final dogs = await client
          .from('dogs')
          .select()
          .eq('owner_id', userId)
          .order('created_at');
      final dogIds = (dogs as List).map((d) => d['id'] as String).toList();

      final walks = await client
          .from('walks')
          .select()
          .eq('user_id', userId)
          .order('walk_date');
      final weightHistory = dogIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await client
              .from('weight_history')
              .select()
              .inFilter('dog_id', dogIds)
              .order('recorded_date');
      final tasks = await client
          .from('daily_tasks')
          .select()
          .eq('user_id', userId)
          .order('task_date');
      final redeemed = await client
          .from('redeemed_rewards')
          .select()
          .eq('user_id', userId)
          .order('redeemed_date');

      final export = {
        'app': 'Vitail',
        'exported_at': DateTime.now().toIso8601String(),
        'profile': profile,
        'dogs': dogs,
        'walks': walks,
        'weight_history': weightHistory,
        'daily_tasks': tasks,
        'redeemed_rewards': redeemed,
      };

      // Pretty-printed JSON in the temp dir, handed to the OS share sheet
      // so the user can save it, email it, etc.
      final json = const JsonEncoder.withIndent('  ').convert(export);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/vitail_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(json);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Your Vitail data export',
      );
    } catch (_) {
      showVitailSnackVia(messenger,
          'Could not export your data. Check your connection.',
          type: VitailSnackType.error);
    }
    if (mounted) setState(() => _isExporting = false);
  }

  // ----------------------------------------------------------------- sign out

  void _showSignOutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardFill,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Log out', style: style(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  _signOut(allDevices: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: coral,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Log out this device',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  _signOut(allDevices: true);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Log out on all devices',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: Text('Cancel',
                    style: style(14, color: muted, weight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut({required bool allDevices}) async {
    setState(() => _isSigningOut = true);
    try {
      // Global revokes ALL of the user's refresh tokens — every signed-in
      // device is logged out. Local only clears this device's session.
      await Supabase.instance.client.auth.signOut(
        scope: allDevices ? SignOutScope.global : SignOutScope.local,
      );
    } catch (_) {
      // If the server call fails, still clear the local session and leave.
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ----------------------------------------------------------- delete account

  Future<void> _confirmDeleteAccount() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardFill,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Delete account?',
                  style: style(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'This permanently deletes your profile, dogs, walks, weight '
                'history, photos and redeemed rewards.',
                style: style(13, color: muted, weight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  _deleteAccount();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Delete my account',
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              Text(
                'This action cannot be undone.',
                textAlign: TextAlign.center,
                style: style(11.5, color: muted, weight: FontWeight.w500),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: Text('Cancel',
                    style: style(14, color: muted, weight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    try {
      // Runs the delete-account Edge Function. The function derives the
      // user from our JWT, so nothing identifying is sent in the body.
      final res = await Supabase.instance.client.functions
          .invoke('delete-account');

      if (res.status != 200) {
        throw Exception(res.data?.toString() ?? 'Failed (${res.status})');
      }

      // Session is dead server-side; clear it locally and leave.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) setState(() => _isDeleting = false);
      showVitailSnackVia(
          messenger, 'Could not delete account. Please try again.',
          type: VitailSnackType.error);
    }
  }

  // ------------------------------------------------------------------ widgets

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text('Settings', style: style(22, weight: FontWeight.w700)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: SvgPicture.asset('assets/icons/onboarding-back.svg',
                width: 24,
                height: 24,
                // Black stroke baked into the SVG — invisible on dark.
                colorFilter: _isDark
                    ? const ColorFilter.mode(Color(0xFFF4F0E9), BlendMode.srcIn)
                    : null),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(text,
            style: style(12, color: color ?? muted, weight: FontWeight.w700)
                .copyWith(letterSpacing: 1.2)),
      );

  Widget _card({required Widget child}) => Container(
        constraints: const BoxConstraints(minHeight: 79),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: cardFill,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: border),
        ),
        child: child,
      );

  Widget _toggleCard(
          {required String title,
          required String subtitle,
          required bool value,
          required ValueChanged<bool> onChanged}) =>
      _card(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: style(15)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style:
                          style(12.5, color: muted, weight: FontWeight.w500)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _tappableCard(
          {required Widget child, required VoidCallback? onTap}) =>
      InkWell(
        borderRadius: BorderRadius.circular(_cardRadius),
        onTap: onTap,
        child: _card(child: child),
      );

  Widget _navCard(
          {required String title,
          String? subtitle,
          Widget? trailing,
          required VoidCallback? onTap}) =>
      _tappableCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: style(15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            style(12.5, color: muted, weight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: muted),
          ],
        ),
      );

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final email =
        Supabase.instance.client.auth.currentUser?.email ?? 'Not signed in';
    final isDark = themeNotifier.value == ThemeMode.dark;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  _sectionLabel('APPEARANCE'),
                  _toggleCard(
                    title: 'Dark mode',
                    subtitle: 'Use dark theme',
                    value: isDark,
                    onChanged: _setDarkMode,
                  ),

                  _sectionLabel('NOTIFICATIONS'),
                  _toggleCard(
                    title: 'Walk reminders',
                    subtitle: 'A daily nudge to get out and walk',
                    value: _notificationsEnabled,
                    onChanged: _setWalkReminders,
                  ),
                  const SizedBox(height: 12),
                  _navCard(
                    title: 'Remind me at',
                    subtitle: _notificationsEnabled
                        ? TimeOfDay(
                                hour: _reminderHour, minute: _reminderMinute)
                            .format(context)
                        : 'Turn on walk reminders to pick a time',
                    trailing: Icon(Icons.schedule, color: muted),
                    onTap: _notificationsEnabled ? _pickReminderTime : null,
                  ),

                  _sectionLabel('YOUR DOG'),
                  _navCard(
                    title: 'Edit dog profile',
                    subtitle: 'Name, breed, weight and more',
                    onTap: _openEditProfile,
                  ),

                  _sectionLabel('DATA'),
                  _navCard(
                    title: 'Export my data',
                    subtitle:
                        "Download a JSON copy of everything you've logged",
                    trailing: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.download_outlined, color: muted),
                    onTap: _isExporting ? null : _exportData,
                  ),

                  _sectionLabel('ABOUT'),
                  _card(
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('App version', style: style(15))),
                        Text('1.0.0',
                            style: style(14,
                                color: muted, weight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _navCard(
                    title: 'Privacy policy',
                    onTap: () => showVitailSnack(context, 'Coming soon',
                        type: VitailSnackType.info),
                  ),

                  _sectionLabel('ACCOUNT'),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style(15)),
                        const SizedBox(height: 4),
                        Text('Signed in',
                            style: style(12.5,
                                color: muted, weight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _tappableCard(
                    onTap: _isSigningOut ? null : _showSignOutSheet,
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Log out',
                                style: style(15, color: Colors.red))),
                        if (_isSigningOut)
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          Icon(Icons.chevron_right, color: muted),
                      ],
                    ),
                  ),

                  _sectionLabel('DANGER ZONE', color: Colors.red),
                  _tappableCard(
                    onTap: _isDeleting ? null : _confirmDeleteAccount,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Delete account',
                                style: style(15, color: Colors.red))),
                        if (_isDeleting)
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red))
                        else
                          Icon(Icons.chevron_right, color: muted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}