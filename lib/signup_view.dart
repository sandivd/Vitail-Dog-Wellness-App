import 'vitail_loading.dart';
import 'package:flutter/material.dart';
import 'password_field.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Signup presentation, independent of the existing authentication handlers.
class SignupView extends StatelessWidget {
  const SignupView({super.key, required this.emailController,
    required this.passwordController, required this.confirmPasswordController, required this.isLoading,
    required this.onSignUp, required this.onGoogleLogin,
    required this.onSignIn, this.onContinueWithCode});

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSignUp;
  final VoidCallback onGoogleLogin;
  final VoidCallback onSignIn;
  final VoidCallback? onContinueWithCode;

  Widget _lucideIcon(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = switch (name) {
      'mail' => const Size(22, 18),
      'lock-keyhole' => const Size(20, 22),
      _ => const Size(24, 24),
    };
    return SizedBox(width: 24, height: 24, child: Center(
      child: SvgPicture.asset('assets/icons/lucide-$name.svg',
        key: ValueKey('lucide-$name'), width: size.width, height: size.height,
        colorFilter: ColorFilter.mode(colorScheme.onSurfaceVariant, BlendMode.srcIn)),
    ));
  }

  InputDecoration _decoration(BuildContext context, String label, String icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: label,
      filled: true,
      fillColor: colorScheme.surface,
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 22, right: 10), child: _lucideIcon(context, icon)),
      prefixIconConstraints: const BoxConstraints(minWidth: 56),
      hintStyle: TextStyle(fontFamily: 'PlusJakartaSans', color: colorScheme.onSurfaceVariant, fontSize: 15, fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: colorScheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(padding: const EdgeInsets.fromLTRB(34, 0, 26, 24),
                      child: AutofillGroup(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: MediaQuery.paddingOf(context).top + 102),
                          Text('Create Account', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 32, height: 1.25, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                          const SizedBox(height: 9),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('A journey of walks & rewards for your dog starts here...',
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant))),
                          const SizedBox(height: 34),
                          TextField(controller: emailController, decoration: _decoration(context, 'Email', 'mail'),
                            keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username], autocorrect: false,
                            style: TextStyle(fontFamily: 'PlusJakartaSans', color: colorScheme.onSurface)),
                          const SizedBox(height: 6),
                          PasswordField(controller: passwordController, decoration: _decoration(context, 'Password (min 6 chars)', 'lock-keyhole'),
                            autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.next,
                            style: TextStyle(fontFamily: 'PlusJakartaSans', color: colorScheme.onSurface)),
                          const SizedBox(height: 6),
                          PasswordField(controller: confirmPasswordController, decoration: _decoration(context, 'Confirm Password', 'lock-keyhole'),
                            autofillHints: const [AutofillHints.newPassword], textInputAction: TextInputAction.done,
                            onSubmitted: (_) { if (!isLoading) onSignUp(); },
                            style: TextStyle(fontFamily: 'PlusJakartaSans', color: colorScheme.onSurface)),
                          const SizedBox(height: 24),
                          ElevatedButton(onPressed: isLoading ? null : onSignUp,
                            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary,
                              elevation: 0, minimumSize: const Size.fromHeight(54),
                              shape: const StadiumBorder(), textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w700)),
                            child: isLoading ? const SizedBox(width: 22, height: 22,
                              child: VitailLoading(semanticsLabel: 'Creating account'))
                              : const Text('Sign up')),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: Divider(color: colorScheme.outline)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text('OR', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant))),
                            Expanded(child: Divider(color: colorScheme.outline)),
                          ]),
                          const SizedBox(height: 16),
                          OutlinedButton(onPressed: isLoading ? null : onGoogleLogin,
                            style: OutlinedButton.styleFrom(foregroundColor: colorScheme.onSurface, backgroundColor: colorScheme.surface,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              side: BorderSide(color: colorScheme.outline), minimumSize: const Size.fromHeight(54),
                              shape: const StadiumBorder(), textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600)),
                            child: Stack(alignment: Alignment.center, children: [
                              SizedBox(width: double.infinity, child: Text('Continue with Google', textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurface))),
                              Align(alignment: Alignment.centerLeft,
                                child: SvgPicture.asset('assets/brand/google-logo.svg',
                                  key: const ValueKey('google-logo'), width: 20, height: 20)),
                            ])),
                          const SizedBox(height: 13),
                          TextButton(onPressed: isLoading ? null : onSignIn,
                            style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
                            child: Text.rich(TextSpan(children: [
                              TextSpan(text: "Already have an account? ", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                              TextSpan(text: 'Sign in', style: TextStyle(color: colorScheme.primary)),
                            ]), textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600))),
                        ],
                      )),
                    ),
                  )),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}