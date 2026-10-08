import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'onboarding_style.dart';
import 'vitail_snack.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.dog});

  final Map<String, dynamic> dog;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _pollTimer;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    final response = await Supabase.instance.client.auth.getUser();
    if (!mounted) return;
    if (response.user?.emailConfirmedAt != null) {
      _pollTimer?.cancel();
      _goToProfile();
    }
  }

  void _goToProfile() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _resendEmail() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null || _resending) return;
    setState(() => _resending = true);
    try {
      await Supabase.instance.client.auth.resend(type: OtpType.signup, email: email);
      if (!mounted) return;
      showVitailSnack(context, 'Verification email sent.',
          type: VitailSnackType.success);
    } catch (e) {
      if (!mounted) return;
      showVitailSnack(context, 'Could not resend email: $e',
          type: VitailSnackType.error);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'your email';
    return OnboardingPage(
      title: 'Check your email',
      children: [
        const SizedBox(height: 20),
        const Center(child: OnboardingBadge(icon: 'mail')),
        const SizedBox(height: 20),
        Text(
          "We've sent a verification link to $email. Verify to finish joining as a carer.",
          textAlign: TextAlign.center,
          style: OnboardingStyle.text(13, color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _resending ? null : _resendEmail,
            child: Text('Resend email', style: OnboardingStyle.text(13, color: OnboardingStyle.coral, weight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _goToProfile,
          style: OnboardingStyle.primaryButton,
          child: Text('Continue', style: OnboardingStyle.text(16, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'You can keep using the app while you verify',
            style: OnboardingStyle.text(12, color: OnboardingStyle.muted, weight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}