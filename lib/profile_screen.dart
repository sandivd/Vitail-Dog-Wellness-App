import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'package:fl_chart/fl_chart.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dogData;
  int _totalPoints = 0;
  bool _isLoading = true;
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  double _totalDistanceKm = 0.0;
  List<Map<String, dynamic>> _weightHistory = [];
  double _weightChange = 0.0;
  final _weightInputController = TextEditingController();

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

      final walksResponse = await Supabase.instance.client
          .from('walks')
          .select('distance_meters')
          .eq('user_id', userId);

      // NEW: Fetch weight history
      final weightResponse = await Supabase.instance.client
          .from('weight_history')
          .select()
          .eq('dog_id', dogResponse?['id'])
          .order('recorded_date', ascending: true);

      double totalDistanceMeters = 0;
      for (var walk in walksResponse) {
        totalDistanceMeters += (walk['distance_meters'] as num).toDouble();
      }

      setState(() {
        _dogData = dogResponse;
        _totalPoints = profileResponse['total_points'] ?? 0;
        _totalDistanceKm = totalDistanceMeters / 1000;
        _weightHistory = List<Map<String, dynamic>>.from(weightResponse);
        
        // Calculate weight change (latest vs previous)
        if (_weightHistory.length >= 2) {
          double latest = (_weightHistory.last['weight_kg'] as num).toDouble();
          double previous = (_weightHistory[_weightHistory.length - 2]['weight_kg'] as num).toDouble();
          _weightChange = latest - previous;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _editDogDetails() async {
    // Pre-fill the text fields with current data
    _ageController.text = (_dogData?['age'] ?? 0).toString();
    _weightController.text = (_dogData?['weight'] ?? 0).toString();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Dog Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age (years)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dogId = _dogData?['id'];
                  await Supabase.instance.client.from('dogs').update({
                    'age': double.tryParse(_ageController.text) ?? 0.0,
                    'weight': double.tryParse(_weightController.text) ?? 0.0,
                  }).eq('id', dogId);
                  
                  if (context.mounted) Navigator.pop(context);
                  _fetchProfile(); // Refresh the UI
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logNewWeight() async {
    _weightInputController.clear();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Weight'),
          content: TextField(
            controller: _weightInputController,
            decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  double newWeight = double.tryParse(_weightInputController.text) ?? 0.0;
                  if (newWeight <= 0) return;
                  
                  await Supabase.instance.client.from('weight_history').insert({
                    'dog_id': _dogData?['id'],
                    'weight_kg': newWeight,
                  });

                  // Update the main dogs table too
                  await Supabase.instance.client.from('dogs').update({
                    'weight': newWeight,
                  }).eq('id', _dogData?['id']);

                  // Complete the daily weight task!
                  await _completeDailyTask('weight_done');

                  if (context.mounted) Navigator.pop(context);
                  _fetchProfile(); // Refresh UI
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Helper to complete daily tasks
  Future<void> _completeDailyTask(String taskColumn) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // Try to update, if it doesn't exist, insert
    await Supabase.instance.client.from('daily_tasks').upsert({
      'user_id': userId,
      'task_date': today,
      taskColumn: true,
    }, onConflict: 'user_id, task_date');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _editDogDetails,
          ),
        ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _weightChange >= 0 ? Colors.orange[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_weightChange >= 0 ? '+' : ''}${_weightChange.toStringAsFixed(1)}kg recently', 
                        style: TextStyle(color: _weightChange >= 0 ? Colors.orange[800] : Colors.green[800], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // The Line Chart
                _weightHistory.length > 1 
                  ? SizedBox(
                      height: 100,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _weightHistory.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), (e.value['weight_kg'] as num).toDouble());
                              }).toList(),
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 4,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.1)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Text('Log at least 2 weights to see the graph', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logNewWeight,
                    icon: const Icon(Icons.scale),
                    label: const Text('Log New Weight'),
                  ),
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
                _buildMilestoneIcon(Icons.directions_walk, '${_totalDistanceKm.toStringAsFixed(1)}km', 'Walked'),
                _buildMilestoneIcon(Icons.task_alt, '0', 'Quests'), // Set to 0 since we don't have quests yet
                _buildMilestoneIcon(Icons.attach_money, '\$$_totalPoints', 'Rewards'),
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