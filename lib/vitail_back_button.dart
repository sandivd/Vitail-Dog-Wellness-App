import 'package:flutter/material.dart';

import 'vitail_icon.dart';

/// The app's one back button: Lucide chevron-left in a 48dp tap target.
///
/// Place it flush with the top-left corner of the screen's SafeArea (outside
/// any page padding); it adds its own 8dp left inset, so every screen's
/// chevron lands on the same 20dp gutter, 12dp below the safe area.
class VitailBackButton extends StatelessWidget {
  const VitailBackButton({super.key, required this.onPressed, this.color});

  /// Null disables the button (e.g. while saving).
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: IconButton(
      tooltip: 'Back',
      onPressed: onPressed,
      icon: VitailIcon('chevron-left', size: 24, color: color),
    ),
  );
}
