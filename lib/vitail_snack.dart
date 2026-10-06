import 'vitail_icon.dart';
import 'package:flutter/material.dart';

/// The one way Vitail shows snackbars.
///
/// Screens used to roll their own `ScaffoldMessenger.showSnackBar(...)` —
/// some raw `Colors.red`, some stock, plus three copy-pasted `_snack()`
/// helpers. This keeps errors/toasts looking like part of the app (floating,
/// softly rounded, Plus Jakarta Sans from the theme) and consistent across
/// light/dark because every colour comes from the ColorScheme.
enum VitailSnackType { error, success, info }

/// Shows a themed snackbar, replacing whatever is already showing (queued
/// snackbars feel laggy when a failing button is tapped twice).
void showVitailSnack(
  BuildContext context,
  String message, {
  VitailSnackType type = VitailSnackType.info,
}) =>
    _show(ScaffoldMessenger.of(context), message, type);

/// Same as [showVitailSnack] for call sites that captured
/// `ScaffoldMessenger.of(context)` before an `await` (the app's usual
/// use_build_context_synchronously workaround) and can't touch that
/// context afterwards.
void showVitailSnackVia(
  ScaffoldMessengerState messenger,
  String message, {
  VitailSnackType type = VitailSnackType.info,
}) =>
    _show(messenger, message, type);

void _show(
  ScaffoldMessengerState messenger,
  String message,
  VitailSnackType type,
) {
  // Read the theme off the messenger's own context so the "Via" variant
  // never needs a (possibly stale) BuildContext.
  final colorScheme = Theme.of(messenger.context).colorScheme;

  // error: warm terracotta from colorScheme.error (harmonises with the coral
  // primary instead of stock Material red); success: the app's tertiary green
  // with the dark-ink pairing the tertiary buttons already use; info:
  // Material 3's inverse surface — what the old unstyled snackbars looked like.
  final (Color background, Color foreground, String icon) = switch (type) {
    VitailSnackType.error => (
        colorScheme.error,
        colorScheme.onError,
        'circle-alert',
      ),
    VitailSnackType.success => (
        colorScheme.tertiary,
        const Color(0xFF241C24),
        'circle-check',
      ),
    VitailSnackType.info => (
        colorScheme.inverseSurface,
        colorScheme.onInverseSurface,
        'info',
      ),
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            VitailIcon(icon, color: foreground, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
}
