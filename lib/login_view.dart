import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Login presentation, independent of the existing authentication handlers.
class LoginView extends StatelessWidget {
  const LoginView({super.key, required this.emailController,
    required this.passwordController, required this.isLoading,
    required this.onEmailLogin, required this.onGoogleLogin,
    required this.onSignUp});

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onEmailLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onSignUp;

  static const cream = Color(0xFFFBF5EA);
  static const coral = Color(0xFFDC755C);
  static const ink = Color(0xFF241C24);
  static const muted = Color(0xFF6B5F66);
  static const outline = Color(0xFFDED2D6);

  Widget _lucideIcon(String name) {
    final size = switch (name) {
      'mail' => const Size(22, 18),
      'lock-keyhole' => const Size(20, 22),
      _ => const Size(24, 24),
    };
    return SizedBox(width: 24, height: 24, child: Center(
      child: SvgPicture.asset('assets/icons/lucide-$name.svg',
        key: ValueKey('lucide-$name'), width: size.width, height: size.height,
        colorFilter: const ColorFilter.mode(outline, BlendMode.srcIn)),
    ));
  }

  InputDecoration _decoration(String label, String icon) => InputDecoration(
    hintText: label,
    prefixIcon: Padding(padding: const EdgeInsets.only(left: 22, right: 10), child: _lucideIcon(icon)),
    prefixIconConstraints: const BoxConstraints(minWidth: 56),
    hintStyle: const TextStyle(fontFamily: 'PlusJakartaSans', color: Color(0xFFD3CFD1), fontSize: 15, fontWeight: FontWeight.w400),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: outline)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30),
      borderSide: const BorderSide(color: coral, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(brightness: Brightness.light, useMaterial3: true, fontFamily: 'PlusJakartaSans',
        colorScheme: ColorScheme.fromSeed(seedColor: coral),
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'PlusJakartaSans', bodyColor: ink, displayColor: ink)),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: cream,
                      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 34, bottom: 43),
                      child: Column(children: [
                        Semantics(label: 'Vitail', image: true,
                          child: SizedBox(width: 188, height: 180,
                            child: ClipRect(child: Stack(children: [
                              Positioned(left: -7, top: -54, width: 270, height: 270,
                                child: Image.asset('assets/brand/vitail-logo.png', excludeFromSemantics: true)),
                            ])),
                          ),
                        ),
                      ]),
                    ),
                    Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(padding: const EdgeInsets.fromLTRB(30, 17, 30, 0),
                        child: AutofillGroup(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Log in', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 32, height: 1.25, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 23),
                            TextField(controller: emailController, decoration: _decoration('Email', 'mail'),
                              keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username], autocorrect: false,
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', color: ink)),
                            const SizedBox(height: 6),
                            TextField(controller: passwordController, decoration: _decoration('Password', 'lock-keyhole'),
                              obscureText: true, autocorrect: false, enableSuggestions: false,
                              autofillHints: const [AutofillHints.password], textInputAction: TextInputAction.done,
                              onSubmitted: (_) { if (!isLoading) onEmailLogin(); },
                              style: const TextStyle(fontFamily: 'PlusJakartaSans', color: ink)),
                            const SizedBox(height: 24),
                            ElevatedButton(onPressed: isLoading ? null : onEmailLogin,
                              style: ElevatedButton.styleFrom(backgroundColor: coral, foregroundColor: Colors.white,
                                elevation: 0, minimumSize: const Size.fromHeight(54),
                                shape: const StadiumBorder(), textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w700)),
                              child: isLoading ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Signing in'))
                                : const Text('Continue with email')),
                            const SizedBox(height: 14),
                            const Row(children: [
                              Expanded(child: Divider(color: outline)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 5),
                                child: Text('OR', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600, color: muted))),
                              Expanded(child: Divider(color: outline)),
                            ]),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: isLoading ? null : onGoogleLogin,
                              style: OutlinedButton.styleFrom(foregroundColor: ink,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                side: const BorderSide(color: outline), minimumSize: const Size.fromHeight(54),
                                shape: const StadiumBorder(), textStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600)),
                              child: Stack(alignment: Alignment.center, children: [
                                const SizedBox(width: double.infinity, child: Text('Continue with Google', textAlign: TextAlign.center)),
                                Align(alignment: Alignment.centerLeft,
                                  child: SvgPicture.asset('assets/brand/google-logo.svg',
                                    key: const ValueKey('google-logo'), width: 20, height: 20)),
                              ])),
                            const SizedBox(height: 13),
                            TextButton(onPressed: isLoading ? null : onSignUp,
                              style: TextButton.styleFrom(foregroundColor: coral),
                              child: const Text.rich(TextSpan(children: [
                                TextSpan(text: "Don't have an account? ", style: TextStyle(color: muted)),
                                TextSpan(text: 'Sign up', style: TextStyle(color: coral)),
                              ]), textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w600))),
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
      ),
    );
  }
}
