import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_sharing.dart';
import 'edit_profile_screen.dart';
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

  if (userId == null) return const OnboardingScreen();

  final link = await primaryDogForCurrentUser();
  if (link == null) return const OnboardingScreen();

  return link.role == 'carer'
      ? EditProfileScreen(dog: link.dog)
      : const HomeScreen();
}