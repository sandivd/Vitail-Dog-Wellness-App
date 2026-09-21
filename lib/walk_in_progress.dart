import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'walk_summary.dart';

// ---------------------------------------------------------------------------
// Design tokens from the Figma spec for this screen. Hardcoded on purpose:
// the app's ColorScheme doesn't define surfaceVariant, so reading it from the
// theme silently falls back to Material's default purple-grey tint (the
// "blended" colours after the merge). This is a fixed light design, matching
// the approach used by onboarding / edit profile.
// ---------------------------------------------------------------------------
const Color _kPageBg = Colors.white; // Sheet background
const Color _kCardBg = Color(0xFFF9F7F3); // Stat / hygiene / add-photo cards
const Color _kInk = Color(0xFF211F1D); // Primary text
const Color _kMuted = Color(0xFF6E6A63); // Secondary text
const Color _kBorder = Color(0xFFDBD7D1); // Borders + progress track
const Color _kAvatarBg = Color(0xFFE5E1DB); // Dog avatar placeholder
const Color _kCoral = Color(0xFFDC755C); // Finish btn, progress, polyline
const Color _kBlue = Color(0xFF5F98BD); // "LIVE MAP" accent

class WalkInProgress extends StatefulWidget {
  const WalkInProgress({super.key, this.selectedDogs});

  final List<Map<String, dynamic>>? selectedDogs;

  @override
  State<WalkInProgress> createState() => _WalkInProgressState();
}

class _WalkInProgressState extends State<WalkInProgress> {
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

  /// Goal from the dogs' stored daily_goal_minutes (set at onboarding),
  /// so the progress bar matches the Home screen rings. Group walks use
  /// the highest goal among the selected dogs.
  int get _goalMinutes {
    if (_dogs.isEmpty) return 30;
    final goals = _dogs
        .map((dog) => (dog['daily_goal_minutes'] as num?)?.toInt() ?? 30);
    return goals.reduce((a, b) => a > b ? a : b);
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WalkSummary(
          distanceMeters: _totalDistance,
          elapsedSeconds: _elapsedSeconds,
          goalMinutes: _goalMinutes,
          dogs: _dogs,
          hygiene: _hygiene,
          routePoints: List<LatLng>.from(_polylinePoints),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
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
                  color: _kCoral,
                  width: 6,
                ),
              },
            ),
          ),

          // Top bar: back chevron + title, sits above the map.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        size: 28, color: _kInk),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                        fontFamily: 'PlusJakartaSans',
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
                  color: _kPageBg,
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
                          color: _kBorder,
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
                            color: _kBlue,
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
                        const Expanded(
                          child: _StatCard(label: 'TIME', value: '00:00'),
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

                    // Goal progress card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _kCardBg,
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
                              color: _kInk,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 6,
                              backgroundColor: _kBorder,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(_kCoral),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hygiene log per dog
                    if (_dogs.isNotEmpty) ...[
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'HYGIENE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kMuted,
                                letterSpacing: 0.6,
                                fontFamily: 'PlusJakartaSans',
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
                                color: _kMuted,
                                letterSpacing: 0.6,
                                fontFamily: 'PlusJakartaSans',
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
                                color: _kMuted,
                                letterSpacing: 0.6,
                                fontFamily: 'PlusJakartaSans',
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kCardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _kAvatarBg,
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
                                        color: _kInk,
                                        fontFamily: 'PlusJakartaSans',
                                      ),
                                    ),
                                    Text(
                                      breed,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _kMuted,
                                        fontFamily: 'PlusJakartaSans',
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
                          const SnackBar(
                              content: Text('Photo picker coming soon')),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _kCardBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text(
                            '+ Add photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
                              fontFamily: 'PlusJakartaSans',
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
                        color: _kMuted,
                        letterSpacing: 0.6,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Walk note...',
                        hintStyle: const TextStyle(
                            color: _kMuted, fontFamily: 'PlusJakartaSans'),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _kCoral),
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
                                backgroundColor: _kCardBg,
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
                                  color: _kInk,
                                  fontFamily: 'PlusJakartaSans',
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
                                backgroundColor: _kCoral,
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
                                  fontFamily: 'PlusJakartaSans',
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
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kMuted,
              letterSpacing: 0.6,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kInk,
              fontFamily: 'PlusJakartaSans',
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kCoral : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _kCoral : _kBorder,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _kInk,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}