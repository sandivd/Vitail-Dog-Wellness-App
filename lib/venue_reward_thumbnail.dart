import 'package:flutter/material.dart';
import 'reward_image_placeholder.dart';

class VenueRewardThumbnail extends StatelessWidget {
  const VenueRewardThumbnail({super.key, this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: photoUrl == null || photoUrl!.isEmpty
          ? const RewardImagePlaceholder()
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, synchronous) =>
                  synchronous || frame != null
                  ? child
                  : const RewardImagePlaceholder(),
              errorBuilder: (_, error, stack) => const RewardImagePlaceholder(),
            ),
    ),
  );
}
