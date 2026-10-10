import 'microchip_validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardOffer {
  const RewardOffer({
    required this.id,
    required this.title,
    required this.partnerName,
    required this.pointsCost,
    required this.category,
    this.partnerId,
    this.description = '',
  });

  factory RewardOffer.fromJson(Map<String, dynamic> row) => RewardOffer(
    id: row['id'] as String,
    title: row['title'] as String,
    partnerName: row['partner_name'] as String,
    pointsCost: (row['points_cost'] as num).toInt(),
    category: row['category'] as String? ?? '',
    partnerId: row['partner_id']?.toString(),
    description: (row['description'] as String?)?.trim() ?? '',
  );

  final String id;
  final String title;
  final String partnerName;
  final int pointsCost;
  final String category;
  final String? partnerId;
  final String description;
}

class RedeemedReward {
  const RedeemedReward({
    required this.title,
    required this.promoCode,
    this.rewardId,
    this.partnerName,
    this.pointsCost,
    this.category,
    this.isCollected = false,
  });

  factory RedeemedReward.fromJson(Map<String, dynamic> row) => RedeemedReward(
    title: row['reward_title'] as String,
    promoCode: row['promo_code'] as String,
    rewardId: row['reward_id'] as String?,
    partnerName: row['partner_name'] as String?,
    pointsCost: (row['points_cost'] as num?)?.toInt(),
    category: row['category'] as String?,
    isCollected: row['is_collected'] as bool? ?? false,
  );

  final String title;
  final String promoCode;
  final String? rewardId;
  final String? partnerName;
  final int? pointsCost;
  final String? category;
  final bool isCollected;

  RewardOffer get detailsOffer => RewardOffer(
    id: rewardId ?? '',
    title: title,
    partnerName: partnerName ?? 'Partner details unavailable',
    pointsCost: pointsCost ?? 0,
    category: category ?? '',
  );
}

class RewardsCatalogue {
  const RewardsCatalogue({
    required this.points,
    required this.offers,
    this.canRedeem = false,
  });
  final int points;
  final bool canRedeem;
  final List<RewardOffer> offers;
}

abstract class RewardsRepository {
  Future<RewardsCatalogue> loadCatalogue();
  Future<List<RedeemedReward>> loadRedeemed();
  Future<RedeemedReward> redeem(RewardOffer offer, String requestId);
  Future<RedeemedReward> collect(RedeemedReward reward);
}

class SupabaseRewardsRepository implements RewardsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view your rewards.');
    return id;
  }

  Future<bool> _hasValidMicrochip(String userId) async {
    final dog = await _client
        .from('dogs')
        .select('microchip_number')
        .eq('owner_id', userId)
        .maybeSingle();
    return dog != null &&
        microchipNumberError(dog['microchip_number']?.toString() ?? '') == null;
  }

  @override
  Future<RewardsCatalogue> loadCatalogue() async {
    final userId = _userId;
    final profile = await _client
        .from('profiles')
        .select('total_points')
        .eq('id', userId)
        .single();
    final eligible = await _hasValidMicrochip(userId);
    final rows = await _client.from('rewards').select();
    return RewardsCatalogue(
      points: (profile['total_points'] as num?)?.toInt() ?? 0,
      offers: rows.map(RewardOffer.fromJson).toList(),
      canRedeem: eligible,
    );
  }

  @override
  Future<List<RedeemedReward>> loadRedeemed() async {
    final userId = _userId;
    final rows = await _client
        .from('redeemed_rewards')
        .select('reward_title,promo_code')
        .eq('user_id', userId);
    final receipts = await _client
        .from('reward_receipts')
        .select()
        .eq('user_id', userId);
    final byCode = {for (final row in receipts) row['promo_code']: row};
    return rows
        .map((row) => RedeemedReward.fromJson(byCode[row['promo_code']] ?? row))
        .toList();
  }

  @override
  Future<RedeemedReward> redeem(RewardOffer offer, String requestId) async {
    if (!await _hasValidMicrochip(_userId)) {
      throw StateError('Add a valid microchip number to unlock rewards.');
    }
    final result = await _client.rpc(
      'redeem_offer',
      params: {'p_reward_id': offer.id, 'p_request_id': requestId},
    );
    return RedeemedReward.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<RedeemedReward> collect(RedeemedReward reward) async {
    final result = await _client.rpc(
      'collect_reward',
      params: {'p_promo_code': reward.promoCode},
    );
    final collected = RedeemedReward.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
    if (!collected.isCollected) {
      throw StateError('Collection was not confirmed.');
    }
    return collected;
  }
}
