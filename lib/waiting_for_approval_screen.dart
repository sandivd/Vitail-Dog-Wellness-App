import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_sharing.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_style.dart';

class WaitingForApprovalScreen extends StatefulWidget {
  const WaitingForApprovalScreen({super.key, required this.request});

  final JoinRequest request;

  @override
  State<WaitingForApprovalScreen> createState() =>
      _WaitingForApprovalScreenState();
}

class _WaitingForApprovalScreenState extends State<WaitingForApprovalScreen> {
  Timer? _timer;
  late String _status = widget.request.status;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    if (_status == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openHome());
    } else if (_status == 'pending') {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final String? status = await joinRequestStatus(widget.request.id);
      if (!mounted || status == null || status == _status) return;
      setState(() => _status = status);
      if (status != 'pending') _timer?.cancel();
      if (status == 'approved') _openHome();
    } catch (e) {
      debugPrint('Status check failed: ${e.runtimeType}');
    }
  }

  void _openHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _timer?.cancel();
    try {
      if (_status == 'pending') await cancelJoinRequest(widget.request.id);
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Leaving join request failed: ${e.runtimeType}');
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool declined = _status == 'declined';
    final String dog = widget.request.dogName;
    return OnboardingPage(
      title: declined ? 'Request declined' : 'Waiting for approval',
      subtitle: declined
          ? "$dog's owner didn't approve this request. Check with them and try again."
          : "We've asked $dog's owner to approve you. This page updates by itself.",
      busy: _leaving,
      children: [
        const SizedBox(height: 32),
        Center(
          child: OnboardingBadge(
            icon: declined ? Icons.close : Icons.schedule,
            color: declined ? OnboardingStyle.coral : null,
          ),
        ),
        const SizedBox(height: 32),
        if (!declined) ...[
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: OnboardingStyle.coral),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: _leaving ? null : _leave,
              child: Text('Cancel request',
                  style: OnboardingStyle.text(13,
                      color: OnboardingStyle.muted, weight: FontWeight.w500)),
            ),
          ),
        ] else
          ElevatedButton(
            onPressed: _leaving ? null : _leave,
            style: OnboardingStyle.primaryButton,
            child: Text('Back to log in',
                style: OnboardingStyle.text(16, color: Colors.white)),
          ),
      ],
    );
  }
}