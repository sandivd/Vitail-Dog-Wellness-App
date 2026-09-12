import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'choose_dog_profiles.dart';


class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  GoogleMapController? mapController;
  
  // Variables to track the walk
  bool _isWalking = false;
  double _totalDistance = 0.0;
  final List<LatLng> _polylinePoints = [];
  StreamSubscription<Position>? _positionStream;
  bool _microchipVerified = false;
  bool _isCheckingMicrochip = true;
  final _microchipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkMicrochipStatus();
  }

  Future<void> _checkMicrochipStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final dogResponse = await Supabase.instance.client
          .from('dogs')
          .select('microchip_number')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();

      setState(() {
        _microchipVerified = dogResponse?['microchip_number'] != null && 
                             (dogResponse?['microchip_number'] as String).length == 15;
        _isCheckingMicrochip = false;
      });
    } catch (e) {
      setState(() => _isCheckingMicrochip = false);
    }
  }

  Future<void> _showMicrochipDialog() async {
    _microchipController.clear();
    await showDialog(
      context: context,
      barrierDismissible: false, // Force them to enter it!
      builder: (context) {
        return AlertDialog(
          title: const Text('Verify Your Dog 🐶'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To track walks and earn points, you must verify your dog by entering their 15-digit microchip number.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _microchipController,
                decoration: const InputDecoration(
                  labelText: 'Microchip Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 15, // Prevents typing more than 15
              ),
            ],
          ),
          actions: [
            ElevatedButton(   // start or stop walk button
              onPressed: () async {
                String chip = _microchipController.text.trim();
                
                // Validation: exactly 15 characters and only numbers
                if (chip.length != 15 || int.tryParse(chip) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Must be exactly 15 digits (numbers only).'), backgroundColor: Colors.red),
                  );
                  return;
                }



                try {
                  final userId = Supabase.instance.client.auth.currentUser!.id;
                  
                  // Save to database
                  await Supabase.instance.client.from('dogs').update({
                    'microchip_number': chip,
                  }).eq('owner_id', userId);

                  setState(() {
                    _microchipVerified = true;
                  });

                  if (context.mounted) Navigator.pop(context);
                  
                  // Now actually start the walk!
                  _toggleWalk();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Verify & Start'),
            ),
          ],
        );
      },
    );
  }
  
  // Default camera position (Melbourne)
  static const LatLng _melbourne = LatLng(-37.8136, 144.9631);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // 1. Ask the user for location permissions
  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  // 2. Start or Stop the walk
  Future<void> _toggleWalk() async {
    if (_isWalking) {
      // Stop the walk
      _positionStream?.cancel();
      setState(() {
        _isWalking = false;
      });
      
      // Show a popup with the final distance
      showDialog(
        context: context,
        barrierDismissible: false, // User must click the button
        builder: (context) => AlertDialog(
          title: const Text('Walk Finished!'),
          content: Text('You walked ${_totalDistance.toStringAsFixed(0)} meters!'),
          actions: [
            TextButton(
              onPressed: () async {
                int pointsEarned = (_totalDistance / 100).floor();
                final userId = Supabase.instance.client.auth.currentUser!.id;

                try {
                  // 1. Save the walk
                  await Supabase.instance.client.from('walks').insert({
                    'user_id': userId,
                    'distance_meters': _totalDistance,
                    'duration_seconds': 1800, 
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
                  DateTime today = DateTime.now();
                  DateTime todayDateOnly = DateTime(today.year, today.month, today.day);
                  int newStreak = 1; // Default to 1 if streak is broken

                  if (lastWalkStr != null) {
                    DateTime lastWalk = DateTime.parse(lastWalkStr);
                    DateTime lastWalkDateOnly = DateTime(lastWalk.year, lastWalk.month, lastWalk.day);
                    int diffInDays = todayDateOnly.difference(lastWalkDateOnly).inDays;
                    
                    if (diffInDays == 1) {
                      newStreak = currentStreak + 1; // Consecutive day!
                    } else if (diffInDays == 0) {
                      newStreak = currentStreak; // Already walked today
                    }
                  }

                  // 4. COMPLETE WALK QUEST & GIVE POINTS
                  if (_totalDistance >= 1000) {
                    final today = DateTime.now().toIso8601String().split('T')[0];
                    
                    // Check if walk quest was already done today
                    final taskCheck = await Supabase.instance.client
                        .from('daily_tasks')
                        .select('walk_done')
                        .eq('user_id', userId)
                        .eq('task_date', today)
                        .maybeSingle();

                    // If NOT done yet, give 50 points!
                    if (taskCheck?['walk_done'] != true) {
                      pointsEarned += 50; 
                      
                      // Mark task as done
                      await Supabase.instance.client.from('daily_tasks').upsert({
                        'user_id': userId,
                        'task_date': today,
                        'walk_done': true,
                      }, onConflict: 'user_id, task_date');
                    }
                  }

                  // 5. Update profile with new points, streak, and date
                  await Supabase.instance.client.from('profiles').update({
                    'total_points': currentPoints + pointsEarned,
                    'daily_streak': newStreak,
                    'last_walk_date': todayDateOnly.toIso8601String().split('T')[0],
                  }).eq('id', userId);

                  if (context.mounted) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                } catch (e) {
                  // If internet drops, catch the error so the app doesn't crash!
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Network error: Could not save walk. Check your connection.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    // Still navigate home, but the walk data is lost.
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                }
              },
              child: const Text('Nice!'),
            ),
          ],
        ),
      );
    } 
    
    // start walk
    else {
      // insert "Ready for walk?"" with dog profile page here
      // Wait for dog selection or confirmation
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChooseDogProfiles()),
      );

      // Cancel if user dismissed without selecting or confirming
      if (result == null || !mounted) return;


      bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to track your walk.')),
        );
        return;
      }

      setState(() {
        _isWalking = true;
        _totalDistance = 0.0;
        _polylinePoints.clear();
      });

      // Start listening to GPS updates
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Only update every 5 meters to save battery
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
        (Position position) {
          LatLng newPoint = LatLng(position.latitude, position.longitude);
          
          setState(() {
            if (_polylinePoints.isNotEmpty) {
              // Calculate distance from the last point and add to total
              double distance = Geolocator.distanceBetween(
                _polylinePoints.last.latitude,
                _polylinePoints.last.longitude,
                newPoint.latitude,
                newPoint.longitude,
              );
              _totalDistance += distance;
            }
            _polylinePoints.add(newPoint);
          });

          // Move the camera to follow the user
          mapController?.animateCamera(
            CameraUpdate.newLatLng(newPoint),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingMicrochip) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _melbourne,
              zoom: 16.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: {
              Polyline(
                polylineId: const PolylineId('walk_route'),
                points: _polylinePoints,
                color: Colors.green,
                width: 6,
              ),
            },
          ),
          
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              // Intercept the button press!
              onPressed: () {
                if (!_microchipVerified) {
                  _showMicrochipDialog();
                } else {
                  _toggleWalk();
                }
              },
              icon: Icon(_isWalking ? Icons.stop : Icons.play_arrow, size: 30),
              label: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _isWalking ? 'End Walk' : 'Start Walk',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWalking ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}