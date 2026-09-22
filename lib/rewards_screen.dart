import 'vitail_loading.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'check_in_screen.dart';

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
      final rewardsResponse =
          await Supabase.instance.client.from('rewards').select();

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

  Future<void> _checkIn(Map<String, dynamic> reward) async {
    final cost = (reward['points_cost'] as num).toInt();
    if (_userPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points!')),
      );
      return;
    }

    // Only the reward's id is passed through — the DB looks up the cost
    // and title itself inside redeem_reward, so the client can't redeem
    // at a discounted price.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckInScreen(
          rewardId: reward['id'] as String,
          title: reward['title'] as String,
          partnerName: reward['partner_name'] as String,
        ),
      ),
    );

    if (!mounted) return;
    // When we return, refresh the points
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: VitailLoading()));
    }

    // Group rewards by category
    final vouchers =
        _rewards.where((r) => r['category'] == 'Partner Vouchers').toList();
    final perks =
        _rewards.where((r) => r['category'] == 'Premium Perks').toList();

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
                const Text('YOUR WALLET',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('$_userPoints pts',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Active Adventurer',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  color: Colors.lightGreenAccent,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
                Text('${goldTierTarget - _userPoints} pts to Gold Tier',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Partner Vouchers Section
          const Text('Partner Vouchers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...vouchers.map((r) => _buildRewardCard(r)),
          const SizedBox(height: 24),

          // Premium Perks Section
          const Text('Premium Perks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...perks.map((r) => _buildRewardCard(r)),
        ],
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    int cost = (reward['points_cost'] as num).toInt();
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
                  Text(reward['partner_name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(reward['title'],
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$cost pts',
                      style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canAfford ? () => _checkIn(reward) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text('Check in'),
            ),
          ],
        ),
      ),
    );
  }
}