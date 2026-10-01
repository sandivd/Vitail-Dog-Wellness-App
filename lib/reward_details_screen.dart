import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'rewards_data.dart';
import 'detail_image_header.dart';
import 'venue_detail.dart';
import 'reward_image_placeholder.dart';
import 'vitail_snack.dart';

/// Offer details with the linked Explore venue.
class RewardDetailsScreen extends StatelessWidget {
  const RewardDetailsScreen({
    super.key,
    required this.offer,
    required this.canRedeem,
    required this.onRedeem,
    this.redemption,
    this.onCheckIn,
    this.onShowCode,
    this.venue,
    this.onGoHere,
    this.venueStatus,
    this.distanceLabel,
  });

  final String? distanceLabel;
  final VenueInfo? venue;
  final VoidCallback? onGoHere;
  final String? venueStatus;
  final RewardOffer offer;
  final bool canRedeem;
  final VoidCallback onRedeem;
  final RedeemedReward? redemption;
  final VoidCallback? onCheckIn;
  final VoidCallback? onShowCode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? const Color(0xFF242321) : Colors.white;
    final softColor = dark ? const Color(0xFF302E2B) : const Color(0xFFF9F7F3);
    final borderColor = dark ? colors.outline : const Color(0xFFDBD7D1);
    return Scaffold(
      backgroundColor: colors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DetailImageHeader(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue?.name ?? offer.partnerName,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: onGoHere,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.tertiary,
                      foregroundColor: const Color(0xFF241C24),
                      side: BorderSide(color: borderColor, width: 1.5),
                      minimumSize: const Size(110, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('GO HERE'),
                  ),
                  if (venueStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(venueStatus!),
                  ],
                  if (venue != null && venue!.details.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      venue!.details.trim(),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _info(
                              context,
                              'HOURS',
                              venue?.hoursLabel ?? 'Not provided',
                            ),
                          ),
                          VerticalDivider(
                            width: 28,
                            thickness: 1,
                            color: borderColor,
                          ),
                          Expanded(
                            child: _info(
                              context,
                              'DISTANCE',
                              distanceLabel ?? 'Not confirmed',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'OFFERS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const RewardImagePlaceholder(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  if (offer.category.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      offer.category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: redemption != null
                                        ? SvgPicture.asset(
                                            'assets/icons/reward-redeemed-check.svg',
                                            width: 38,
                                            height: 38,
                                            semanticsLabel: 'Redeemed',
                                          )
                                        : Text(
                                            '${NumberFormat.decimalPattern('en').format(offer.pointsCost)} pts',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                              color: colors.primary,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: redemption != null
                              ? onCheckIn
                              : canRedeem
                              ? onRedeem
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: softColor,
                            disabledForegroundColor: colors.onSurfaceVariant,
                            minimumSize: const Size(double.infinity, 48),
                            textStyle: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            redemption != null
                                ? redemption!.isCollected
                                      ? 'VIEW COLLECTION'
                                      : 'CHECK IN'
                                : canRedeem
                                ? 'REDEEM'
                                : 'LOCKED',
                          ),
                        ),
                        if (redemption != null && onShowCode != null)
                          TextButton(
                            onPressed: onShowCode,
                            child: const Text('View code'),
                          ),
                        if (redemption == null && !canRedeem) ...[
                          const SizedBox(height: 8),
                          Text(
                            'You need more points to redeem this offer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}
