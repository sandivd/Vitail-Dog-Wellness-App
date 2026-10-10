import 'package:cached_network_image/cached_network_image.dart';
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

/// Round dog photo; falls back to the same Vitail-dog logo the reward
/// offers use when there is no photo (or it fails to load).
class DogAvatar extends StatelessWidget {
  const DogAvatar({super.key, required this.photoUrl, required this.size});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF393632)
          : const Color(0xFFD9D5CF),
      padding: EdgeInsets.all(size * 0.13),
      child: const WhiteRewardLogo(),
    );
    final url = photoUrl;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url == null || url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
