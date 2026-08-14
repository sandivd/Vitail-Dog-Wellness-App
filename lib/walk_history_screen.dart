import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For formatting dates

class WalkHistoryScreen extends StatefulWidget {
  const WalkHistoryScreen({super.key});

  @override
  State<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends State<WalkHistoryScreen> {
  List<Map<String, dynamic>> _walks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWalks();
  }

  Future<void> _fetchWalks() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('walks')
          .select()
          .eq('user_id', userId)
          .order('walk_date', ascending: false);

      setState(() {
        _walks = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walk History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _walks.isEmpty
              ? const Center(child: Text('No walks yet. Go outside!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _walks.length,
                  itemBuilder: (context, index) {
                    final walk = _walks[index];
                    // Format the date nicely
                    final date = DateTime.parse(walk['walk_date']);
                    String formattedDate = DateFormat('EEE, MMM d').format(date);
                    double distance = (walk['distance_meters'] as num).toDouble();
                    int points = walk['points_earned'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.directions_walk, color: Colors.white),
                        ),
                        title: Text('${distance.toStringAsFixed(0)} meters'),
                        subtitle: Text(formattedDate),
                        trailing: Text('+ $points pts', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}