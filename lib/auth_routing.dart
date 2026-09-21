import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Decides where a signed-in user should land:
/// [OnboardingScreen] until they've added their first dog, then [HomeScreen].
///
/// We check for a dog rather than a profiles row because the profile is
/// created automatically at sign-up (DB trigger) — the dog is what marks
/// onboarding as complete.
Future<Widget> resolvePostAuthScreen() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  // Defensive: callers only run this right after a successful sign-in.
  if (userId == null) return const OnboardingScreen();

  final dog = await client
      .from('dogs')
      .select('id')
      .eq('owner_id', userId)
      .limit(1)
      .maybeSingle();

  return dog == null ? const OnboardingScreen() : const HomeScreen();
}