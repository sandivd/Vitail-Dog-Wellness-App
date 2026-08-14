import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false, // User must click the button to close
        builder: (dialogContext) => AlertDialog(
          title: const Text('Walk Finished!'),
          content: Text('You walked ${_totalDistance.toStringAsFixed(2)} meters!\nPoints earned: ${(_totalDistance / 100).floor()}'),
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

                  // 2. Fetch current points and streak
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

                  // 4. Update profile with new points, streak, and date
                  await Supabase.instance.client.from('profiles').update({
                    'total_points': currentPoints + pointsEarned,
                    'daily_streak': newStreak,
                    'last_walk_date': todayDateOnly.toIso8601String().split('T')[0],
                  }).eq('id', userId);

                  if (context.mounted) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving walk: $e')),
                    );
                  }
                }
              },
              child: const Text('Nice!'),
            ),
          ],
        ),
      );
    } else {
      // Start the walk
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) return;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isWalking 
          ? 'Walking... ${_totalDistance.toStringAsFixed(0)} m' 
          : 'Dog Walk'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _melbourne,
              zoom: 16.0, // Zoomed in a bit more
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            // Draw the walking path!
            polylines: {
              Polyline(
                polylineId: const PolylineId('walk_route'),
                points: _polylinePoints,
                color: Colors.green,
                width: 6,
              ),
            },
          ),
          
          // The Start/Stop Walk Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _toggleWalk,
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