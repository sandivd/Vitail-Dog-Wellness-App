import 'package:flutter/material.dart';

/// Theme-aware colours shared by the Figma screens.
/// Light-only tints keep their original design; dark surfaces come from the
/// app's ColorScheme so changing the theme also rebuilds every consumer.
class VitailColors {
  const VitailColors._(this.scheme);

  factory VitailColors.of(BuildContext context) =>
      VitailColors._(Theme.of(context).colorScheme);

  final ColorScheme scheme;

  bool get isDark => scheme.brightness == Brightness.dark;

  Color tint(Color light, [Color? dark]) =>
      isDark ? (dark ?? scheme.surfaceContainerHighest) : light;

  Color get background => tint(const Color(0xFFF4F0E9), scheme.surface);
  Color get card => tint(Colors.white, scheme.surfaceContainerLow);
  Color get softCard => tint(const Color(0xFFF9F7F3));
  Color get ink => tint(const Color(0xFF211F1D), scheme.onSurface);
  Color get muted => tint(const Color(0xFF6E6A63), scheme.onSurfaceVariant);
  Color get border => tint(const Color(0xFFDBD7D1), scheme.outline);
  Color get avatar =>
      tint(const Color(0xFFE5E1DB), scheme.surfaceContainerHigh);
  Color get teal => tint(const Color(0xFFD1E8E1), scheme.secondaryContainer);
  Color get greenPale =>
      tint(const Color(0xFFEAF0D8), scheme.tertiaryContainer);
  Color get greenInk =>
      tint(const Color(0xFF5A7224), scheme.onTertiaryContainer);

  // Brand accents stay recognisable in both modes.
  Color get coral => const Color(0xFFDC755C);
  Color get blue => const Color(0xFF5F98BD);
  Color get green => const Color(0xFFAEC568);
}
