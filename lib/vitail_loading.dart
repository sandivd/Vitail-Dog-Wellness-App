import 'vitail_icon.dart';
import 'package:flutter/material.dart';

/// Shared, bundled brand animation: no network or video player required.
class VitailLoading extends StatelessWidget {
  const VitailLoading({
    super.key,
    this.size = 48,
    this.semanticsLabel = 'Loading',
  });

  final double size;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    liveRegion: true,
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        MediaQuery.disableAnimationsOf(context)
            ? 'assets/brand/vitail-mark.png'
            : 'assets/brand/vitail-loading.webp',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const VitailIcon('paw-print'),
      ),
    ),
  );
}
