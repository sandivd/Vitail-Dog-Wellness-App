import 'vitail_colors.dart';
import 'package:flutter/material.dart';

import 'dog_sharing.dart';
import 'onboarding_goal_screen.dart';
import 'onboarding_style.dart';
import 'vitail_snack.dart';
import 'waiting_for_approval_screen.dart';

class JoinWithCodeScreen extends StatefulWidget {
  const JoinWithCodeScreen({super.key});

  @override
  State<JoinWithCodeScreen> createState() => _JoinWithCodeScreenState();
}

class _JoinWithCodeScreenState extends State<JoinWithCodeScreen> {
  VitailColors get _colors => VitailColors.of(context);

  OnboardingStyle get _style => OnboardingStyle.of(context);

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
    showVitailSnack(context, text, type: VitailSnackType.error);
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
    hintStyle: _style.text(14, color: _style.muted, weight: FontWeight.w400),
    filled: true,
    fillColor: _colors.card,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    enabledBorder: _border(_style.border),
    disabledBorder: _border(_style.border),
    focusedBorder: _border(_style.coral),
    border: _border(_style.border),
  );

  @override
  Widget build(BuildContext context) => OnboardingPage(
    title: 'Join with a code',
    subtitle: "Ask the dog's owner for their invite code",
    busy: _busy,
    children: [
      const SizedBox(height: 28),
      Text('Invite code', style: _style.text(13, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _codeController,
        enabled: !_busy,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.next,
        style: _style.text(14, weight: FontWeight.w500),
        decoration: _decoration('e.g. AUG-7F3K'),
      ),
      const SizedBox(height: 16),
      Text('Your name', style: _style.text(13, weight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: _nameController,
        enabled: !_busy,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _continue(),
        style: _style.text(14, weight: FontWeight.w500),
        decoration: _decoration('So the owner knows who you are'),
      ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _busy ? null : _continue,
        style: _style.primaryButton,
        child: _busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _style.muted,
                ),
              )
            : Text('Send request', style: _style.text(16, color: Colors.white)),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          "The dog's owner will be asked to approve you",
          style: _style.text(12, color: _style.muted, weight: FontWeight.w500),
        ),
      ),
    ],
  );
}
