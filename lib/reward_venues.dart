import 'package:supabase_flutter/supabase_flutter.dart';

import 'rewards_data.dart';
import 'venue_detail.dart';

/// Shared matching rule for both directions of rewards / Explore navigation.
VenueInfo? venueForReward(RewardOffer offer, List<VenueInfo> venues) {
  final partnerId = offer.partnerId?.trim();
  if (partnerId != null && partnerId.isNotEmpty) {
    final matches = venues
        .where((venue) => venue.partnerId == partnerId)
        .toList();
    if (matches.length == 1) return matches.single;
  } else {
    final matches = venues
        .where(
          (venue) =>
              venue.name.trim().toLowerCase() ==
              offer.partnerName.trim().toLowerCase(),
        )
        .toList();
    if (matches.length == 1) return matches.single;
  }
  // Temporary demo fallback automatically stops when more venues are added.
  return venues.length == 1 ? venues.single : null;
}

Future<List<VenueInfo>> loadRewardVenues() async {
  final rows = await Supabase.instance.client.from('partnered_venues').select();
  return rows.map(VenueInfo.fromJson).toList();
}
