import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared Lucide stroke icons. Assets come from the official Lucide library.
class VitailIcon extends StatelessWidget {
  const VitailIcon(
    this.name, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });
  final String name;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final iconColor =
        color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    final dimension = size ?? theme.size ?? 24;
    return SvgPicture.asset(
      'assets/icons/lucide-$name.svg',
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(
        iconColor.withValues(alpha: iconColor.a * (theme.opacity ?? 1)),
        BlendMode.srcIn,
      ),
      semanticsLabel: semanticLabel,
    );
  }
}
