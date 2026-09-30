import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_routing.dart';
import 'auth_style.dart';
import 'home_screen.dart';
import 'password_field.dart';
import 'vitail_snack.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _saveNewPassword() async {
    if (_isSaving) return;
    if (!PasswordField.isValid(_passwordController.text)) {
      showVitailSnack(context, 'Password must be 6–64 characters.',
          type: VitailSnackType.error);
      return;
    }
    if (_passwordController.text.trim() != _confirmController.text.trim()) {
      showVitailSnack(context, 'Passwords do not match!', type: VitailSnackType.error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // The recovery session from the email link authorises this —
      // no old password required.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );

      if (!mounted) return;
      showVitailSnack(context, 'Password updated — welcome back!',
          type: VitailSnackType.success);

      // The user now has a valid session, so route like a normal sign-in.
      Widget destination;
      try {
        destination = await resolvePostAuthScreen();
      } catch (_) {
        destination = const HomeScreen(); // same fallback as AuthGate
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destination),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showVitailSnack(context, 'Could not update password: ${e.message}',
            type: VitailSnackType.error);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        showVitailSnack(
            context, 'Network error: could not update. Check your connection.',
            type: VitailSnackType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Recovery flows replace the entire navigation stack, so back has
    // nowhere to go — trap it rather than let it exit the flow.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 40, 30, 24),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Choose a new password',
                              style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 32,
                                  height: 1.25,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface)),
                          const SizedBox(height: 9),
                          Text(
                            'Create a new password for your account.',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 34),
                          PasswordField(
                            controller: _passwordController,
                            decoration: AuthStyle.field(
                                context, 'New password (min 6 chars)', 'lock-keyhole'),
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.next,
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 6),
                          PasswordField(
                            controller: _confirmController,
                            decoration: AuthStyle.field(
                                context, 'Confirm password', 'lock-keyhole'),
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _saveNewPassword(),
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveNewPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(54),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Set new password'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}