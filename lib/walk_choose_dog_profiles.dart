import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// file imports
import 'walk_in_progress.dart';
import 'exercise_data.dart';

class ChooseDogProfiles extends StatefulWidget {
  const ChooseDogProfiles({super.key});

  @override
  State<ChooseDogProfiles> createState() => _ChooseDogProfilesState();
}

class _ChooseDogProfilesState extends State<ChooseDogProfiles> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _dogs = [];
  final Set<String> _selectedDogIds = {};

    int get _goalMinutes {
    if (_dogs.isEmpty) return 30; // fallback if somehow no dogs were passed in

    final recommended = _dogs.map((dog) {
      final breed = (dog['breed'] ?? '').toString();
      final age = (dog['age'] as num?)?.toDouble() ?? 2.0; // assume adult if age is missing
      return ExerciseData.getRecommendedMinutes(breed, age);
    });

    return recommended.reduce((a, b) => a > b ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _fetchDogs();
  }

  Future<void> _fetchDogs() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('dogs')
          .select()
          .eq('owner_id', userId);

      final List<Map<String, dynamic>> loadedDogs =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        _dogs = loadedDogs;
        // Select all dogs by default if available
        if (loadedDogs.isNotEmpty) {
          _selectedDogIds.addAll(loadedDogs.map((d) => d['id'].toString()));
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dogs: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleDogSelection(String dogId) {
    setState(() {
      if (_selectedDogIds.contains(dogId)) {
        if (_selectedDogIds.length > 1) {
          _selectedDogIds.remove(dogId);
        }
      } else {
        _selectedDogIds.add(dogId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color pageBg = Color(0xFFEFECE6);
    const Color buttonColor = Color(0xFFBA5A3A);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              const Center(
                child: Text(
                  'Ready for a walk?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Dog Cards Area
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: buttonColor))
                    : _dogs.isEmpty
                        ? const Center(
                            child: Text(
                              'No dogs found.\nPlease register a dog first.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.center,
                                  children: _dogs.map((dog) {
                                    final dogId = dog['id'].toString();
                                    final isSelected = _selectedDogIds.contains(dogId);
                                    final name = dog['dog_name'] ?? 'Dog';
                                    final breed = (dog['breed'] ?? 'Unknown').toString().toUpperCase();
                                    final photoUrl = dog['photo_url'];

                                    return GestureDetector(
                                      onTap: () => _toggleDogSelection(dogId),
                                      child: Container(
                                        width: 155,
                                        height: 190,
                                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: isSelected ? buttonColor : Colors.transparent,
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 36,
                                              backgroundColor: const Color(0xFFDDD8CC),
                                              backgroundImage: photoUrl != null && photoUrl.toString().isNotEmpty
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E1E1E),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              breed,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                letterSpacing: 0.8,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF7C776E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'Walk goal for today: $_goalMinutes min', 
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF7C776E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),

              // Start Walk Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _dogs.isEmpty || _selectedDogIds.isEmpty
                        ? null
                        : () {
                            // Return selected dogs list to previous screen
                            final selected = _dogs
                                .where((d) => _selectedDogIds.contains(d['id'].toString()))
                                .toList();
                            Navigator.pushReplacement(  // navigate to Walk In Progress page
                              context,
                              MaterialPageRoute(
                                builder: (context) => WalkInProgress(selectedDogs: selected),
                              ),  
                            );
                          },
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: const Text(
                      'Start walk',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}