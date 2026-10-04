import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'reward_image_placeholder.dart';

/// Common image fallback and back control for reward and venue details.
class DetailImageHeader extends StatelessWidget {
  const DetailImageHeader({super.key, this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 300 + top,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: dark ? const Color(0xFF393632) : const Color(0xFFD9D5CF),
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: const Center(
                child: SizedBox(
                  width: 188,
                  height: 156,
                  child: WhiteRewardLogo(),
                ),
              ),
            ),
          ),
          if (photoUrl != null && photoUrl!.isNotEmpty)
            Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, synchronous) =>
                  synchronous || frame != null
                  ? child
                  : const SizedBox.shrink(),
              errorBuilder: (_, error, stack) => const SizedBox.shrink(),
            ),
          Positioned(
            top: top + 12,
            left: 16,
            child: Material(
              color: dark ? const Color(0xFF242321) : Colors.white,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.15),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                icon: SvgPicture.asset(
                  'assets/icons/reward-details-back.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    colors.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
