import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'rewards_data.dart';
import 'reward_image_placeholder.dart';

/// Offer details from Figma 630:1144. Location data is not yet confirmed.
class RewardDetailsScreen extends StatelessWidget {
  const RewardDetailsScreen({
    super.key,
    required this.offer,
    required this.canRedeem,
    required this.onRedeem,
    this.redemption,
    this.onCheckIn,
    this.onShowCode,
  });

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
            Stack(
              children: [
                Container(
                  height: 300 + MediaQuery.paddingOf(context).top,
                  width: double.infinity,
                  color: dark
                      ? const Color(0xFF393632)
                      : const Color(0xFFD9D5CF),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top,
                    ),
                    child: Center(
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
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  left: 12,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Material(
                        color: cardColor,
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.15),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          padding: const EdgeInsets.all(8),
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
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.partnerName,
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Directions coming soon — we’re confirming this location.',
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.tertiary,
                      foregroundColor: const Color(0xFF241C24),
                      side: BorderSide(color: borderColor, width: 1.5),
                      minimumSize: const Size(110, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('GO HERE'),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
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
                            child: _info(context, 'HOURS', 'Not provided'),
                          ),
                          VerticalDivider(
                            width: 32,
                            thickness: 1,
                            color: borderColor,
                          ),
                          Expanded(
                            child: _info(context, 'DISTANCE', 'Not confirmed'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'OFFERS',
                    style: TextStyle(
                      fontSize: 12,
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
                                      fontSize: 13,
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
                                        fontSize: 11,
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
                                              fontSize: 20,
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
                            minimumSize: const Size(double.infinity, 44),
                            textStyle: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
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
                              fontSize: 12,
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}
