import 'package:flutter/material.dart';

import 'onboarding_style.dart';

class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key});

  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _continue() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the invite code first.')),
      );
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) => OnboardingPage(
        title: 'Join with a code',
        subtitle: "Ask the dog's owner or another carer for their invite code",
        children: [
          const SizedBox(height: 28),
          Text('Invite code', style: OnboardingStyle.text(13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _continue(),
            style: OnboardingStyle.text(14, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'e.g. AUG-7F3K',
              hintStyle: OnboardingStyle.text(14, color: OnboardingStyle.muted, weight: FontWeight.w400),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OnboardingStyle.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OnboardingStyle.coral)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OnboardingStyle.border)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _continue,
            style: OnboardingStyle.primaryButton,
            child: Text('Continue', style: OnboardingStyle.text(16, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "You'll verify your email next",
              style: OnboardingStyle.text(12, color: OnboardingStyle.muted, weight: FontWeight.w500),
            ),
          ),
        ],
      );
}