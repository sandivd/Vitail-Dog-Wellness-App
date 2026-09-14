import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'exercise_data.dart';

class WalkInProgress extends StatefulWidget {
  const WalkInProgress({super.key, this.selectedDogs});

  final List<Map<String, dynamic>>? selectedDogs;

  @override
  State<WalkInProgress> createState() => _WalkInProgressState();
}

class _WalkInProgressState extends State<WalkInProgress> {
  static const Color pageBg = Color(0xFFEFECE6);
  static const Color cardBg = Color(0xFFF3F0EA);
  static const Color buttonColor = Color(0xFFBA5A3A);

  static const LatLng _melbourne = LatLng(-37.8136, 144.9631);

  GoogleMapController? _mapController;

  bool _isWalking = false;
  bool _isPaused = false;
  double _totalDistance = 0.0; // meters
  int _elapsedSeconds = 0;

  final List<LatLng> _polylinePoints = [];
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _noteController = TextEditingController();

  // dogId -> {'pee': bool, 'poo': bool}
  late final Map<String, Map<String, bool>> _hygiene;

  List<Map<String, dynamic>> get _dogs => widget.selectedDogs ?? [];

  String get _title {
    if (_dogs.length > 1) return 'Group walk';
    if (_dogs.isNotEmpty) return (_dogs.first['dog_name'] ?? 'Walk').toString();
    return 'Walk';
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _formattedDistance => (_totalDistance / 1000).toStringAsFixed(2);

  // Recommended walk length, derived from each dog's breed + age.
  // For a group walk we use the highest need among the selected dogs, so
  // every dog in the group gets at least their recommended amount of exercise.
  int get _goalMinutes {
    if (_dogs.isEmpty) return 30; // fallback if somehow no dogs were passed in

    final recommended = _dogs.map((dog) {
      final breed = (dog['breed'] ?? '').toString();
      final age = (dog['age'] as num?)?.toDouble() ?? 2.0; // assume adult if age is missing
      return ExerciseData.getRecommendedMinutes(breed, age);
    });

    return recommended.reduce((a, b) => a > b ? a : b);
  }

  double get _progress =>
      (_elapsedSeconds / (_goalMinutes * 60)).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _hygiene = {
      for (final dog in _dogs)
        dog['id'].toString(): {'pee': false, 'poo': false},
    };
    _startWalk();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    _noteController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _startWalk() async {
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to track your walk.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isWalking = true;
      _isPaused = false;
    });

    _startTimer();
    _startLocationTracking();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 meters to save battery
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (_isPaused || !mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);

      setState(() {
        if (_polylinePoints.isNotEmpty) {
          final distance = Geolocator.distanceBetween(
            _polylinePoints.last.latitude,
            _polylinePoints.last.longitude,
            newPoint.latitude,
            newPoint.longitude,
          );
          _totalDistance += distance;
        }
        _polylinePoints.add(newPoint);
      });

      _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _toggleHygiene(String dogId, String type) {
    setState(() {
      _hygiene[dogId]![type] = !(_hygiene[dogId]![type] ?? false);
    });
  }

  Future<void> _finishWalk() async {
    _timer?.cancel();
    _positionStream?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Walk Finished!'),
        content: Text('You walked ${_totalDistance.toStringAsFixed(0)} meters!'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveWalk();
              if (dialogContext.mounted) {
                Navigator.popUntil(dialogContext, (route) => route.isFirst);
              }
            },
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWalk() async {
    int pointsEarned = (_totalDistance / 100).floor();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final todayStr = todayDateOnly.toIso8601String().split('T')[0];

    try {
      // 1. Save the walk
      // NOTE: 'walk_date' is required here — profile_screen.dart and
      // walk_history_screen.dart both read/filter on it, and omitting it
      // was causing every insert to fail (surfacing as "network error").
      await Supabase.instance.client.from('walks').insert({
        'user_id': userId,
        'walk_date': todayStr,
        'distance_meters': _totalDistance,
        'duration_seconds': _elapsedSeconds,
        'points_earned': pointsEarned,
      });

      // 2. Fetch current points, streak, and last walk date
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('total_points, daily_streak, last_walk_date')
          .eq('id', userId)
          .single();

      int currentPoints = profileRes['total_points'] ?? 0;
      int currentStreak = profileRes['daily_streak'] ?? 0;
      String? lastWalkStr = profileRes['last_walk_date'];

      // 3. Calculate new streak
      int newStreak = 1;

      if (lastWalkStr != null) {
        final lastWalk = DateTime.parse(lastWalkStr);
        final lastWalkDateOnly =
            DateTime(lastWalk.year, lastWalk.month, lastWalk.day);
        final diffInDays = todayDateOnly.difference(lastWalkDateOnly).inDays;

        if (diffInDays == 1) {
          newStreak = currentStreak + 1;
        } else if (diffInDays == 0) {
          newStreak = currentStreak;
        }
      }

      // 4. Complete walk quest & give bonus points
      if (_totalDistance >= 1000) {
        final taskCheck = await Supabase.instance.client
            .from('daily_tasks')
            .select('walk_done')
            .eq('user_id', userId)
            .eq('task_date', todayStr)
            .maybeSingle();

        if (taskCheck?['walk_done'] != true) {
          pointsEarned += 50;

          await Supabase.instance.client.from('daily_tasks').upsert({
            'user_id': userId,
            'task_date': todayStr,
            'walk_done': true,
          }, onConflict: 'user_id, task_date');
        }
      }

      // 5. Update profile with new points, streak, and date
      await Supabase.instance.client.from('profiles').update({
        'total_points': currentPoints + pointsEarned,
        'daily_streak': newStreak,
        'last_walk_date': todayStr,
      }).eq('id', userId);
    } on PostgrestException catch (e) {
      // Database/query errors (bad column, RLS denial, constraint violation, etc.)
      // Surface the real message instead of mislabeling this as a network issue.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save walk: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Genuine connectivity/other errors.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Network error: Could not save walk. Check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          // Map fills the whole screen; the sheet slides over it.
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition:
                  const CameraPosition(target: _melbourne, zoom: 16.0),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              polylines: {
                Polyline(
                  polylineId: const PolylineId('walk_route'),
                  points: _polylinePoints,
                  color: buttonColor,
                  width: 6,
                ),
              },
            ),
          ),

          // Top bar: back button + title, sits above the map.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        size: 28, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // Draggable panel with walk details. Drag/swipe to reveal more map.
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.62,
            minChildSize: 0.28,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.28, 0.62, 0.92],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: pageBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Tapping this collapses the sheet to reveal the map.
                    Center(
                      child: TextButton(
                        onPressed: () {
                          _sheetController.animateTo(
                            0.28,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const Text(
                          'LIVE MAP',
                          style: TextStyle(
                            color: Color(0xFF6B8CAE),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Time / Distance
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(label: 'TIME', value: _formattedTime),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'DISTANCE',
                            value: '$_formattedDistance km',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Goal progress bar
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_elapsedSeconds ~/ 60} / $_goalMinutes min',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 6,
                              backgroundColor: Colors.black12,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(buttonColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hygiene log per dog
                    if (_dogs.isNotEmpty) ...[
                      Row(
                        children: const [
                          Expanded(
                            child: Text(
                              'HYGIENE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C776E),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'PEE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C776E),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              'POO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C776E),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._dogs.map((dog) {
                        final dogId = dog['id'].toString();
                        final name = dog['dog_name'] ?? 'Dog';
                        final breed = dog['breed'] ?? 'Unknown';
                        final photoUrl = dog['photo_url'];
                        final peeDone = _hygiene[dogId]?['pee'] ?? false;
                        final pooDone = _hygiene[dogId]?['poo'] ?? false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFDDD8CC),
                                backgroundImage: photoUrl != null &&
                                        photoUrl.toString().isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      breed,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF7C776E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: _HygieneButton(
                                  label: 'PEE',
                                  active: peeDone,
                                  onTap: () => _toggleHygiene(dogId, 'pee'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: _HygieneButton(
                                  label: 'POO',
                                  active: pooDone,
                                  onTap: () => _toggleHygiene(dogId, 'poo'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    // Add photo
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Photo picker coming soon')),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text(
                            '+ Add photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Note
                    Text(
                      _dogs.length > 1 ? 'GROUP NOTE' : 'NOTE',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C776E),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Walk note...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE0DCD3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE0DCD3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: buttonColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pause / Finish
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _togglePause,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: cardBg,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: Text(
                                _isPaused ? 'Resume' : 'Pause',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _finishWalk,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: const Text(
                                'Finish',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C776E),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }
}

class _HygieneButton extends StatelessWidget {
  const _HygieneButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const buttonColor = Color(0xFFBA5A3A);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? buttonColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? buttonColor : const Color(0xFFE0DCD3),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF1E1E1E),
          ),
        ),
      ),
    );
  }
}
