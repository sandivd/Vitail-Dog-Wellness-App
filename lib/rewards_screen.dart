import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _userPoints = 0;
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      // Fetch user points
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('total_points')
          .eq('id', userId)
          .single();
      
      // Fetch all rewards
      final rewardsResponse = await Supabase.instance.client
          .from('rewards')
          .select();

      setState(() {
        _userPoints = profileResponse['total_points'] ?? 0;
        _rewards = List<Map<String, dynamic>>.from(rewardsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper function to generate a random 6-character code
  String _generatePromoCode() {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _redeemReward(int cost, String title) async {
    if (_userPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points!')),
      );
      return;
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      int newPoints = _userPoints - cost;

      // 1. Deduct points from user profile
      await Supabase.instance.client.from('profiles').update({
        'total_points': newPoints,
      }).eq('id', userId);

      // 2. Generate the unique 6-digit code
      String promoCode = _generatePromoCode();

      // 3. Save the redeemed code to the database
      await Supabase.instance.client.from('redeemed_rewards').insert({
        'user_id': userId,
        'reward_title': title,
        'promo_code': promoCode,
      });

      setState(() {
        _userPoints = newPoints;
      });

      // 4. Show Success Dialog with the code
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Reward Redeemed! 🎉', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Show this code at $title to claim your reward:', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Text(
                      promoCode,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.green),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: promoCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied to clipboard!')),
                    );
                  },
                  child: const Text('Copy Code'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Group rewards by category
    final vouchers = _rewards.where((r) => r['category'] == 'Partner Vouchers').toList();
    final perks = _rewards.where((r) => r['category'] == 'Premium Perks').toList();

    // Calculate tier progress (Mock: 2000 pts for Gold Tier)
    int goldTierTarget = 2000;
    double progress = (_userPoints / goldTierTarget).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        automaticallyImplyLeading: false, // Hides back button since we use bottom nav
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Wallet Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR WALLET', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('$_userPoints pts', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Active Adventurer', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  color: Colors.lightGreenAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text('${goldTierTarget - _userPoints} pts to Gold Tier', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Partner Vouchers Section
          const Text('Partner Vouchers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...vouchers.map((r) => _buildRewardCard(r)),
          const SizedBox(height: 24),

          // Premium Perks Section
          const Text('Premium Perks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...perks.map((r) => _buildRewardCard(r)),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    int cost = reward['points_cost'];
    bool canAfford = _userPoints >= cost;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward['partner_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(reward['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$cost pts', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canAfford ? () => _redeemReward(cost, reward['title']) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text('Redeem'),
            ),
          ],
        ),
      ),
    );
  }
}