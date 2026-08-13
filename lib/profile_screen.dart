import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dogData;
  int _totalPoints = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      final dogResponse = await Supabase.instance.client
          .from('dogs')
          .select()
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
          
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('total_points')
          .eq('id', userId)
          .single();

      setState(() {
        _dogData = dogResponse;
        _totalPoints = profileResponse['total_points'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Fallbacks in case data is missing
    String dogName = _dogData?['dog_name'] ?? 'Your Dog';
    String breed = _dogData?['breed'] ?? 'Unknown Breed';
    double age = (_dogData?['age'] ?? 0).toDouble();
    double weight = (_dogData?['weight'] ?? 0).toDouble();
    String insurance = _dogData?['insurance_partner'] ?? 'Bow Wow Meow';
    String vaccDate = _dogData?['vaccination_date'] ?? 'Aug 2026';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Dog Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green[100],
                  child: const Icon(Icons.pets, size: 40, color: Colors.green),
                ),
                const SizedBox(height: 12),
                Text(dogName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('$breed • ${age.toStringAsFixed(1)} years • ${weight.toStringAsFixed(1)}kg', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Weight Tracker Card
          _buildSectionCard(
            title: 'Weight Tracker',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stable Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('+0.8kg this month', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Health & Insurance Card
          _buildSectionCard(
            title: 'Health & Insurance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text('Partner: $insurance', style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.vaccines, color: Colors.purple),
                    const SizedBox(width: 8),
                    const Text('C5 Vaccination Status', style: TextStyle(fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text('Up to date ($vaccDate)', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lifetime Milestones Card
          _buildSectionCard(
            title: 'Lifetime Milestones',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMilestoneIcon(Icons.directions_walk, '340km', 'Walked'),
                _buildMilestoneIcon(Icons.task_alt, '18', 'Quests'),
                _buildMilestoneIcon(Icons.attach_money, '\$$_totalPoints', 'Rewards'), // Using points as mock rewards $               
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logout Button
          ElevatedButton.icon(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for section containers
  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Helper widget for milestone row
  Widget _buildMilestoneIcon(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}