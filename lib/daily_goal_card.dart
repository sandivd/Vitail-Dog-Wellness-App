import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'venue_detail.dart';

/// Home-screen card: progress toward today's TIME goal, plus a suggested
/// place to walk (one partnered venue, picked per day by the Home screen).
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({
    super.key,
    required this.currentMinutes,
    required this.goalMinutes,
    this.venue,
    this.onVenueTap,
  });

  final int currentMinutes;
  final int goalMinutes;

  /// Today's suggested walk destination; the suggestion row is hidden
  /// while null (venue still loading, table empty, or fetch failed).
  final VenueInfo? venue;
  final VoidCallback? onVenueTap;

  /// Filled coral play triangle — the Figma's "start a walk" affordance.
  /// Inlined as a raw string because the icon set's lucide-play.svg is a
  /// stroke icon, and this needs the solid fill.
  static const String _playSvg = '''
<svg width="16" height="18" viewBox="0 0 16 18" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M8.78626e-08 2.00059C-0.000104208 1.64868 0.0926453 1.30298 0.268884 0.998383C0.445122 0.693786 0.69861 0.441083 1.00375 0.265789C1.30889 0.090495 1.65488 -0.00118309 2.00679 1.15272e-05C2.3587 0.00120614 2.70406 0.0952313 3.008 0.272593L15.005 7.27059C15.3078 7.44627 15.5591 7.69834 15.7339 8.0016C15.9088 8.30486 16.0009 8.64869 16.0012 8.99873C16.0015 9.34877 15.91 9.69276 15.7357 9.99633C15.5614 10.2999 15.3105 10.5524 15.008 10.7286L3.008 17.7286C2.70406 17.906 2.3587 18 2.00679 18.0012C1.65488 18.0024 1.30889 17.9107 1.00375 17.7354C0.69861 17.5601 0.445122 17.3074 0.268884 17.0028C0.0926453 16.6982 -0.000104208 16.3525 8.78626e-08 16.0006V2.00059Z" fill="#DC755C"/>
</svg>''';

  int get _percent =>
      ((currentMinutes / max(goalMinutes, 1)) * 100).round().clamp(0, 100);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final venue = this.venue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_percent% of daily activity goal completed!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 12),
          // Figma: 19px tall pill bar, blush track (#F8F1F0), green fill.
          LinearProgressIndicator(
            value: (_percent / 100).clamp(0.0, 1.0),
            minHeight: 19,
            borderRadius: BorderRadius.circular(9.5), // stadium ends
            color: colorScheme.tertiary,
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF302E2B)
                    : const Color(0xFFF8F1F0),
          ),
          if (venue != null) ...[
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onVenueTap,
              child: Row(
                children: [
                  SvgPicture.string(_playSvg, width: 16, height: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Visit '),
                          TextSpan(
                            text: venue.name,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(text: ' today!'),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 15, // was 13
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}