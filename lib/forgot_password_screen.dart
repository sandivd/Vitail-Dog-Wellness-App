import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_style.dart';

/// Where the reset email's link sends the user. Must match:
///  - the intent-filter in AndroidManifest.xml
///  - the allowed Redirect URLs in Supabase → Auth → URL Configuration
const String kResetRedirectUrl = 'io.supabase.vitail://reset-password';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red));

  Future<void> _sendResetLink() async {
    if (_isLoading) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Please enter the email you signed up with.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Supabase deliberately never reveals whether the address has an
      // account (emails can't be used to probe for signups) — this only
      // throws if the request itself is invalid (bad redirect, rate limit).
      await Supabase.instance.client.auth
          .resetPasswordForEmail(email, redirectTo: kResetRedirectUrl);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      final rateLimited = e.toString().contains('60 seconds');
      _snack(rateLimited
          ? 'Please wait a minute before requesting another email.'
          : 'Could not send the reset email. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                        icon: SvgPicture.asset('assets/icons/onboarding-back.svg',
                            width: 24,
                            height: 24,
                            // Black stroke baked into the SVG — re-tint on dark.
                            colorFilter: isDark
                                ? const ColorFilter.mode(
                                    Color(0xFFF4F0E9), BlendMode.srcIn)
                                : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
                      child: _sent
                          ? _sentContent(colorScheme)
                          : _formContent(colorScheme),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _formContent(ColorScheme colorScheme) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reset password',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 32,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 9),
          Text(
            "Enter your email and we'll send you a link to get back into your account.",
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 34),
          TextField(
            controller: _emailController,
            decoration: AuthStyle.field(context, 'Email', 'mail'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            onSubmitted: (_) => _sendResetLink(),
            style: TextStyle(
                fontFamily: 'PlusJakartaSans', color: colorScheme.onSurface),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendResetLink,
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
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _sentContent(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read_outlined,
                color: colorScheme.tertiary, size: 32),
          ),
        ),
        const SizedBox(height: 24),
        Text('Check your inbox',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface)),
        const SizedBox(height: 12),
        Text(
          'We sent a reset link to ${_emailController.text.trim()}. '
          'Open it on this phone to choose a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              height: 1.5,
              color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          "Can't find it? Check your spam folder. The link expires after one hour.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              height: 1.5,
              color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(54),
            shape: const StadiumBorder(),
          ),
          child: const Text('Back to log in',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: _isLoading ? null : _sendResetLink,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Resend email',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}