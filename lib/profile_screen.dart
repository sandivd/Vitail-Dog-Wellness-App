import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dogData;
  int _totalPoints = 0;
  bool _isLoading = true;
  double _totalDistanceKm = 0.0;
  List<Map<String, dynamic>> _weightHistory = [];
  double _weightChange = 0.0;
  final _weightInputController = TextEditingController();
  int _totalQuests = 0;

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

      final weightResponse = await Supabase.instance.client
          .from('weight_history')
          .select()
          .eq('dog_id', dogResponse?['id'])
          .order('recorded_date', ascending: true);

      // NEW: Fetch all daily tasks to count completed quests
      final tasksResponse = await Supabase.instance.client
          .from('daily_tasks')
          .select()
          .eq('user_id', userId);

      // Count individual tasks completed
      int questCount = 0;
      for (var task in tasksResponse) {
        if (task['walk_done'] == true) questCount++;
        if (task['weight_done'] == true) questCount++;
      }

      double totalDistanceMeters = 0;
      for (var walk in walksResponse) {
        totalDistanceMeters += (walk['distance_meters'] as num).toDouble();
      }

      setState(() {
        _dogData = dogResponse;
        _totalPoints = profileResponse['total_points'] ?? 0;
        _totalDistanceKm = totalDistanceMeters / 1000;
        _weightHistory = List<Map<String, dynamic>>.from(weightResponse);
        _totalQuests = questCount; // Update the quest count!
        
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




  DateTime _selectedDate = DateTime.now();

  Future<void> _logNewWeight() async {
    _weightInputController.clear();
    _selectedDate = DateTime.now(); // Reset date to today

    await showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder so the dialog updates when we pick a new date
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Log Weight'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date Picker Display
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Weight Input
                  TextField(
                    controller: _weightInputController,
                    decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      double newWeight = double.tryParse(_weightInputController.text) ?? 0.0;
                      if (newWeight <= 0) return;
                      
                      // Check if an entry for this exact date already exists
                      final existingEntry = await Supabase.instance.client
                          .from('weight_history')
                          .select('id')
                          .eq('dog_id', _dogData?['id'])
                          .eq('recorded_date', _selectedDate.toIso8601String().split('T')[0])
                          .maybeSingle();

                      if (existingEntry != null) {
                        // UPDATE existing entry for this date
                        await Supabase.instance.client.from('weight_history').update({
                          'weight_kg': newWeight,
                        }).eq('id', existingEntry['id']);
                      } else {
                        // INSERT new entry
                        await Supabase.instance.client.from('weight_history').insert({
                          'dog_id': _dogData?['id'],
                          'weight_kg': newWeight,
                          'recorded_date': _selectedDate.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
                        });
                      }

                      // Update the main dogs table with the latest weight
                      await Supabase.instance.client.from('dogs').update({
                        'weight': newWeight,
                      }).eq('id', _dogData?['id']);

                      // Complete the daily weight task & give points (Only if they picked today)
                      if (_selectedDate.year == DateTime.now().year && 
                          _selectedDate.month == DateTime.now().month && 
                          _selectedDate.day == DateTime.now().day) {
                        
                        final userId = Supabase.instance.client.auth.currentUser!.id;
                        final today = DateTime.now().toIso8601String().split('T')[0];
                        
                        // 1. Check if weight quest was already done today
                        final taskCheck = await Supabase.instance.client
                            .from('daily_tasks')
                            .select('weight_done')
                            .eq('user_id', userId)
                            .eq('task_date', today)
                            .maybeSingle();

                        // 2. If NOT done yet, give 50 points!
                        if (taskCheck?['weight_done'] != true) {
                          final profileRes = await Supabase.instance.client
                              .from('profiles')
                              .select('total_points')
                              .eq('id', userId)
                              .single();
                          
                          int currentPoints = profileRes['total_points'] ?? 0;
                          await Supabase.instance.client.from('profiles').update({
                            'total_points': currentPoints + 50,
                          }).eq('id', userId);
                        }

                        // 3. Mark task as done
                        await _completeDailyTask('weight_done');
                      }

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
          }
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
            onPressed: () async {
              // Navigate to Settings Screen and refresh profile when returning
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const SettingsScreen())
              );
              _fetchProfile(); // Refresh data in case they changed the dog's name/weight
            },
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
                              belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.1)),
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
                _buildMilestoneIcon(Icons.task_alt, '$_totalQuests', 'Quests'), // <-- Now uses real data!
                _buildMilestoneIcon(Icons.attach_money, '\$$_totalPoints', 'Rewards'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          
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
            color: Colors.black.withValues(alpha: 0.05),
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