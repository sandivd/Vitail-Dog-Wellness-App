import 'package:supabase_flutter/supabase_flutter.dart';

class RewardOffer {
  const RewardOffer({
    required this.id,
    required this.title,
    required this.partnerName,
    required this.pointsCost,
    required this.category,
  });

  factory RewardOffer.fromJson(Map<String, dynamic> row) => RewardOffer(
    id: row['id'] as String,
    title: row['title'] as String,
    partnerName: row['partner_name'] as String,
    pointsCost: (row['points_cost'] as num).toInt(),
    category: row['category'] as String? ?? '',
  );

  final String id;
  final String title;
  final String partnerName;
  final int pointsCost;
  final String category;
}

class RedeemedReward {
  const RedeemedReward({required this.title, required this.promoCode});

  factory RedeemedReward.fromJson(Map<String, dynamic> row) => RedeemedReward(
    title: row['reward_title'] as String,
    promoCode: row['promo_code'] as String,
  );

  // Historical redemptions store the title, not a foreign key to the catalogue.
  // Do not guess a partner or cost by matching potentially duplicate titles.
  final String title;
  final String promoCode;
}

class RewardsCatalogue {
  const RewardsCatalogue({required this.points, required this.offers});
  final int points;
  final List<RewardOffer> offers;
}

abstract class RewardsRepository {
  Future<RewardsCatalogue> loadCatalogue();
  Future<List<RedeemedReward>> loadRedeemed();
}

class SupabaseRewardsRepository implements RewardsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view your rewards.');
    return id;
  }

  @override
  Future<RewardsCatalogue> loadCatalogue() async {
    final userId = _userId;
    final profile = await _client
        .from('profiles')
        .select('total_points')
        .eq('id', userId)
        .single();
    final rows = await _client.from('rewards').select();
    return RewardsCatalogue(
      points: (profile['total_points'] as num?)?.toInt() ?? 0,
      offers: rows.map(RewardOffer.fromJson).toList(),
    );
  }

  @override
  Future<List<RedeemedReward>> loadRedeemed() async {
    // This contract is also used by the original redemption implementation.
    // Filter by the signed-in owner; the database must enforce the same via RLS.
    final rows = await _client
        .from('redeemed_rewards')
        .select('reward_title,promo_code')
        .eq('user_id', _userId);
    return rows.map(RedeemedReward.fromJson).toList();
  }
}
