import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared input styling for the auth screens (forgot/reset password;
/// login and signup can migrate onto this later).
class AuthStyle {
  const AuthStyle._();

  static Widget icon(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = switch (name) {
      'mail' => const Size(22, 18),
      'lock-keyhole' => const Size(20, 22),
      _ => const Size(24, 24),
    };
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/lucide-$name.svg',
          key: ValueKey('lucide-$name'),
          width: size.width,
          height: size.height,
          colorFilter:
              ColorFilter.mode(colorScheme.onSurfaceVariant, BlendMode.srcIn),
        ),
      ),
    );
  }

  static InputDecoration field(BuildContext context, String hint, String icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colorScheme.surface,
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 22, right: 10),
        child: AuthStyle.icon(context, icon),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 56),
      hintStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: colorScheme.onSurfaceVariant,
          fontSize: 15,
          fontWeight: FontWeight.w400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: colorScheme.outline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5)),
    );
  }
}