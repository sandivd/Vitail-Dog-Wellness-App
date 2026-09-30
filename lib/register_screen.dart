import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'password_field.dart';
import 'signup_view.dart';
import 'auth_routing.dart';
import 'vitail_snack.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  // Shared "where do I go after signing in?" step.
  Future<void> _navigateAfterAuth() async {
    final destination = await resolvePostAuthScreen();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  Future<void> _signUp() async {
    if (!PasswordField.isValid(_passwordController.text) || !PasswordField.isValid(_confirmPasswordController.text)) {
      showVitailSnack(context, 'Password must be 6–64 characters.',
          type: VitailSnackType.error);
      return;
    }
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      showVitailSnack(context, 'Passwords do not match!', type: VitailSnackType.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // The profiles row is created automatically by the DB trigger now —
      // no client-side upsert needed (or allowed, for the points columns).
      await _navigateAfterAuth();
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'An error occurred. Please try again.';
      String errorStr = e.toString().toLowerCase();

      if (errorStr.contains('already registered') || errorStr.contains('user already registered')) {
        errorMessage = 'An account with this email already exists.';
      } else if (errorStr.contains('network') || errorStr.contains('failed host lookup')) {
        errorMessage = 'No internet connection.';
      } else if (errorStr.contains('invalid') || errorStr.contains('email_address_invalid') || errorStr.contains('validate email address')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (errorStr.contains('password')) {
        errorMessage = 'Password must be at least 6 characters.';
      }

      showVitailSnack(context, errorMessage, type: VitailSnackType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        serverClientId: '919287771219-6ftvqq0rpgas0ooe00ceofnnr4495iu6.apps.googleusercontent.com',
      ).signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      await _navigateAfterAuth();
    } catch (_) {
      if (!mounted) return;
      showVitailSnack(
        context,
        'Could not sign in with Google. Please try again.',
        type: VitailSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SignupView(
    emailController: _emailController,
    passwordController: _passwordController,
    confirmPasswordController: _confirmPasswordController,
    isLoading: _isLoading,
    onSignUp: _signUp,
    onGoogleLogin: _signInWithGoogle,
    onSignIn: () => Navigator.pop(context),
  );
}