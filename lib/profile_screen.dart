import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'settings_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  int _careScore = 0;
  int _positiveImpact = 0;
  int _needsFocus = 0;
  Map<String, Map<String, dynamic>> _scoreComponents = {};

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
          .select('distance_meters, walk_date')
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
        // Calculate the Care Score
        _calculateCareScore(List<Map<String, dynamic>>.from(walksResponse), dogResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateCareScore(List<Map<String, dynamic>> walks, Map<String, dynamic>? dog) {
    if (dog == null) return;

    // 1. Activity Score (40%) - Based on last 7 days walks
    DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    List recentWalks = walks.where((w) => DateTime.parse(w['walk_date']).isAfter(sevenDaysAgo)).toList();
    
    // We mock daily goal as 30 mins (1800 secs). We currently save duration as 1800 in the DB.
    // So if they did 4 walks in 7 days, 4 days are 100%, 3 days are 0%. Average = (400)/7 = 57%.
    int activityScore = ((recentWalks.length * 100) / 7).round().clamp(0, 100);

    // 2. Vaccinations (20%)
    int vaccScore = dog['vaccination_status'] == 'up_to_date' ? 100 : 0;

    // 3. Microchip (15%)
    int microchipScore = dog['microchip_number'] != null ? 100 : 0;

    // 4. Insurance (15%)
    int insuranceScore = dog['insurance_status'] == 'active' ? 100 : 0;

    // 5. Vet Check-in (10%) - 100 if within 6 months, else 0
    int vetScore = 0;
    if (dog['last_vet_checkup'] != null) {
      DateTime lastVet = DateTime.parse(dog['last_vet_checkup']);
      if (DateTime.now().difference(lastVet).inDays <= 180) {
        vetScore = 100;
      }
    }

    // Calculate overall score
    int totalScore = (activityScore * 0.40 + vaccScore * 0.20 + microchipScore * 0.15 + insuranceScore * 0.15 + vetScore * 0.10).round();

    // Classify components
    int positive = 0;
    int focus = 0;
    
    Map<String, Map<String, dynamic>> components = {
      'Activity (7 days)': {'score': activityScore, 'status': '${recentWalks.length}/7 days active'},
      'Vaccinations': {'score': vaccScore, 'status': vaccScore == 100 ? 'Up to date' : 'Unknown'},
      'Microchip': {'score': microchipScore, 'status': microchipScore == 100 ? 'Linked' : 'Not added'},
      'Insurance': {'score': insuranceScore, 'status': insuranceScore == 100 ? 'Active' : 'Not added'},
      'Vet check-in': {'score': vetScore, 'status': vetScore == 100 ? 'Up to date' : 'Book your next visit'},
    };

    components.forEach((key, value) {
      int score = value['score'];
      if (score >= 70) { positive++; }
      else if (score < 40) { focus++; }
    });

    setState(() {
      _careScore = totalScore;
      _positiveImpact = positive;
      _needsFocus = focus;
      _scoreComponents = components;
    });
  }

    Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,       // Client-side compression
      imageQuality: 70,
    );

    if (image == null) return; // User cancelled

    try {
      final dogId = _dogData?['id'];
      if (dogId == null) return;

      // 1. Generate a completely unique filename every time
      final fileName = 'dog_${dogId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 2. Upload to Supabase Storage (removed upsert: true because filename is unique now)
      await Supabase.instance.client.storage.from('dog_photos').upload(
        fileName,
        File(image.path),
      );

      // 3. Get the new public URL
      final photoUrl = Supabase.instance.client.storage.from('dog_photos').getPublicUrl(fileName);

      // 4. Update the URL in the database
      await Supabase.instance.client.from('dogs').update({
        'photo_url': photoUrl,
      }).eq('id', dogId);

      // 5. Refresh the UI
      _fetchProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating photo: $e'), backgroundColor: Colors.red),
        );
      }
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
                          await Supabase.instance.client.rpc('add_points', params: {'p_amount': 50});
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
            child: GestureDetector(
              onTap: _changeProfilePicture,
              child: Stack(
                children: [
                  CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green[100],
                  backgroundImage: _dogData?['photo_url'] != null 
                      ? CachedNetworkImageProvider(_dogData!['photo_url']) 
                      : null,
                  child: _dogData?['photo_url'] == null
                      ? const Icon(Icons.pets, size: 50, color: Colors.green)
                      : null,
                ),
                  // Camera icon overlay
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
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

          // CARE SCORE CARD
          _buildSectionCard(
            title: 'CARE SCORE',
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // The Score Ring
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _careScore / 100,
                            strokeWidth: 8,
                            color: Colors.green,
                            backgroundColor: Colors.grey[200],
                          ),
                          Text(
                            '$_careScore',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // The Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Updates weekly based on the last 7 days', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 4),
                              Text('$_positiveImpact positive impact', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.orange, size: 16),
                              const SizedBox(width: 4),
                              Text('$_needsFocus needs focus', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                // The Checklist
                Column(
                  children: _scoreComponents.entries.map((entry) {
                    int score = entry.value['score'];
                    Color color = score >= 70 ? Colors.green : (score < 40 ? Colors.orange : Colors.grey);
                    
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.pets, size: 20, color: color),
                      title: Text(entry.key, style: const TextStyle(fontSize: 14)),
                      trailing: Text(entry.value['status'], style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
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