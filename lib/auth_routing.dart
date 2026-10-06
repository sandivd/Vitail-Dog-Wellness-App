import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_sharing.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'waiting_for_approval_screen.dart';

Future<Widget> resolvePostAuthScreen() async {
  final SupabaseClient client = Supabase.instance.client;
  final User? user = client.auth.currentUser;
  if (user == null) return const LoginScreen();

  final DogShare? link = await primaryDogForCurrentUser();
  if (link != null) return const HomeScreen();

  if (user.isAnonymous) {
    final JoinRequest? request = await latestJoinRequest();
    if (request != null && request.status != 'approved') {
      return WaitingForApprovalScreen(request: request);
    }
    await client.auth.signOut();
    return const LoginScreen();
  }

  return const OnboardingScreen();
}