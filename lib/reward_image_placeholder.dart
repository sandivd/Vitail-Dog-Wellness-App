import 'package:flutter/material.dart';

/// Shared fallback for rewards without a confirmed image.
class RewardImagePlaceholder extends StatelessWidget {
  const RewardImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF393632)
            : const Color(0xFFD9D5CF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const WhiteRewardLogo(),
    ),
  );
}

class WhiteRewardLogo extends StatelessWidget {
  const WhiteRewardLogo({super.key});

  @override
  Widget build(BuildContext context) => FittedBox(
    child: SizedBox(
      width: 188,
      height: 156,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: -28.4444,
              top: -66.3624,
              width: 334.8092,
              height: 335.6028,
              child: Image.asset(
                'assets/brand/reward-details-dog.png',
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
