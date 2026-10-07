import 'package:flutter/material.dart';

import 'dog_sharing.dart';
import 'onboarding_goal_screen.dart';
import 'onboarding_style.dart';
import 'waiting_for_approval_screen.dart';

class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key});

  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _continue() async {
    final String code = _codeController.text.trim();
    final String name = _nameController.text.trim();
    if (code.isEmpty) {
      _show('Enter the invite code first.');
      return;
    }
    if (name.isEmpty) {
      _show('Enter your name so the owner knows who you are.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final JoinRequest request = await requestDogAccess(code, name);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        onboardingFadeRoute<void>(WaitingForApprovalScreen(request: request)),
        (route) => false,
      );
    } on JoinCodeException catch (e) {
      if (mounted) _show(e.message);
    } catch (e) {
      debugPrint('Join request failed: $e');
      if (mounted) _show('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: OnboardingStyle.text(14,
            color: OnboardingStyle.muted, weight: FontWeight.w400),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: _border(OnboardingStyle.border),
        disabledBorder: _border(OnboardingStyle.border),
        focusedBorder: _border(OnboardingStyle.coral),
        border: _border(OnboardingStyle.border),
      );

  @override
  Widget build(BuildContext context) => OnboardingPage(
        title: 'Join with a code',
        subtitle: "Ask the dog's owner for their invite code",
        busy: _busy,
        children: [
          const SizedBox(height: 28),
          Text('Invite code',
              style: OnboardingStyle.text(13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _codeController,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            style: OnboardingStyle.text(14, weight: FontWeight.w500),
            decoration: _decoration('e.g. AUG-7F3K'),
          ),
          const SizedBox(height: 16),
          Text('Your name',
              style: OnboardingStyle.text(13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            enabled: !_busy,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _continue(),
            style: OnboardingStyle.text(14, weight: FontWeight.w500),
            decoration: _decoration('So the owner knows who you are'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _continue,
            style: OnboardingStyle.primaryButton,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: OnboardingStyle.muted),
                  )
                : Text('Send request',
                    style: OnboardingStyle.text(16, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "The dog's owner will be asked to approve you",
              style: OnboardingStyle.text(12,
                  color: OnboardingStyle.muted, weight: FontWeight.w500),
            ),
          ),
        ],
      );
}