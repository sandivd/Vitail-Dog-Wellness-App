import 'vitail_map_style.dart';
import 'vitail_colors.dart';
import 'vitail_icon.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'walk_summary.dart';
import 'vitail_snack.dart';

// Page colours follow the current theme through VitailColors.
class WalkInProgress extends StatefulWidget {
  const WalkInProgress({
    super.key,
    this.dog,
    this.plannedRoute,
    this.onProgress,
  });

  final Map<String, dynamic>? dog;
  final List<LatLng>? plannedRoute;
  final WalkProgressCallback? onProgress;

  @override
  State<WalkInProgress> createState() => _WalkInProgressState();
}

// to relay to home screen to display live walking progress
class WalkProgress {
  const WalkProgress({
    required this.elapsedSeconds,
    required this.distanceMeters,
  });

  final int elapsedSeconds;
  final double distanceMeters;
}

final ValueNotifier<WalkProgress?> activeWalkProgress =
    ValueNotifier<WalkProgress?>(null);

typedef WalkProgressCallback = void Function(WalkProgress? progress);

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

  // {'pee': bool, 'poo': bool} for the single dog on this walk.
  late final Map<String, bool> _hygiene;
  XFile? _photo;

  String get _title => (widget.dog?['dog_name'] as String?) ?? 'Walk';

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _formattedDistance => (_totalDistance / 1000).toStringAsFixed(2);

  /// Goal from the dog's stored daily_goal_minutes (set at onboarding), so
  /// the progress bar matches the Home screen ring.
  int get _goalMinutes =>
      (widget.dog?['daily_goal_minutes'] as num?)?.toInt() ?? 30;

  double get _progress =>
      (_elapsedSeconds / (_goalMinutes * 60)).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _hygiene = {'pee': false, 'poo': false};
    _startWalk();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    _noteController.dispose();
    _sheetController.dispose();
    activeWalkProgress.value = null;
    widget.onProgress?.call(null);
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
        showVitailSnack(
          context,
          'Location permission is required to track your walk.',
          type: VitailSnackType.error,
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
    _publishProgress();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) {
        setState(() => _elapsedSeconds++);
        _publishProgress();
      }
    });
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 meters to save battery
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
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
            _publishProgress();
            _mapController?.animateCamera(CameraUpdate.newLatLng(newPoint));
          },
        );
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _toggleHygiene(String type) {
    setState(() {
      _hygiene[type] = !(_hygiene[type] ?? false);
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 75,
    );
    if (image != null && mounted) {
      setState(() => _photo = image);
    }
  }

  void _finishWalk() {
    _timer?.cancel();
    _positionStream?.cancel();

    if (!mounted) return;

    // WalkSummary owns the actual save (atomic save_walk RPC) — this screen
    // just stops tracking and hands off everything it collected: distance,
    // time, goal, dogs, hygiene, the recorded route, and anything the user
    // already picked/typed here so it isn't lost.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WalkSummary(
          distanceMeters: _totalDistance,
          elapsedSeconds: _elapsedSeconds,
          goalMinutes: _goalMinutes,
          dog: widget.dog,
          hygiene: _hygiene,
          routePoints: List<LatLng>.from(_polylinePoints),
          photo: _photo,
          initialNote: _noteController.text,
        ),
      ),
    );
  }

  Set<Polyline> get _polylines {
    final colors = VitailColors.of(context);
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('walk_route'),
        points: _polylinePoints,
        color: colors.coral,
        width: 6,
      ),
    };

    // Route planned on WalkScreen before starting — dashed reference line.
    if (widget.plannedRoute != null && widget.plannedRoute!.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('planned_route'),
          points: widget.plannedRoute!,
          color: colors.isDark ? Colors.white54 : Colors.black45,
          width: 4,
          patterns: [PatternItem.dash(14), PatternItem.gap(10)],
        ),
      );
    }

    return polylines;
  }

  Set<Marker> get _markers {
    if (widget.plannedRoute == null || widget.plannedRoute!.isEmpty) {
      return {};
    }
    return {
      Marker(
        markerId: const MarkerId('planned_destination'),
        position: widget.plannedRoute!.last,
      ),
    };
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _publishProgress() {
    final progress = WalkProgress(
      elapsedSeconds: _elapsedSeconds,
      distanceMeters: _totalDistance,
    );
    activeWalkProgress.value = progress;
    widget.onProgress?.call(progress);
  }

  @override
  Widget build(BuildContext context) {
    final colors = VitailColors.of(context);
    return Scaffold(
      backgroundColor: colors.card,
      body: Stack(
        children: [
          // Map fills the whole screen; the sheet slides over it.
          Positioned.fill(
            child: GoogleMap(
              style: vitailMapStyle(context),
              onMapCreated: (c) {
                _mapController = c;
                if (widget.plannedRoute != null &&
                    widget.plannedRoute!.length >= 2) {
                  final bounds = _boundsFor(widget.plannedRoute!);
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngBounds(bounds, 60),
                    );
                  });
                }
              },
              initialCameraPosition: const CameraPosition(
                target: _melbourne,
                zoom: 16.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              polylines: _polylines,
              markers: _markers,
            ),
          ),

          // Top bar: back chevron + title, sits above the map.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: colors.card,
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  children: [
                    IconButton(
                      icon: VitailIcon(
                        'chevron-left',
                        size: 28,
                        color: colors.ink,
                      ),
                      onPressed: () {
                        if (_isWalking) {
                          Navigator.of(context).pushNamed('/active-walk-home');
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
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
                decoration: BoxDecoration(
                  color: colors.card,
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
                          color: colors.border,
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
                        child: Text(
                          'LIVE MAP',
                          style: TextStyle(
                            color: colors.blue,
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
                          child: _StatCard(
                            label: 'TIME',
                            value: _formattedTime,
                          ),
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
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.softCard,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_elapsedSeconds ~/ 60} / $_goalMinutes min',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _progress,
                              minHeight: 6,
                              backgroundColor: colors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.coral,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Hygiene log for this dog
                    if (widget.dog != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'HYGIENE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.muted,
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
                                color: colors.muted,
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
                                color: colors.muted,
                                letterSpacing: 0.6,
                                fontFamily: 'PlusJakartaSans',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final name = widget.dog!['dog_name'] ?? 'Dog';
                          final breed = widget.dog!['breed'] ?? 'Unknown';
                          final photoUrl = widget.dog!['photo_url'];
                          final peeDone = _hygiene['pee'] ?? false;
                          final pooDone = _hygiene['poo'] ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: colors.softCard,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colors.avatar,
                                  backgroundImage:
                                      photoUrl != null &&
                                          photoUrl.toString().isNotEmpty
                                      ? CachedNetworkImageProvider(photoUrl)
                                      : null,
                                  child: photoUrl == null
                                      ? VitailIcon(
                                          'paw-print',
                                          color: colors.muted,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: colors.ink,
                                          fontFamily: 'PlusJakartaSans',
                                        ),
                                      ),
                                      Text(
                                        breed,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.muted,
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
                                    onTap: () => _toggleHygiene('pee'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 70,
                                  child: _HygieneButton(
                                    label: 'POO',
                                    active: pooDone,
                                    onTap: () => _toggleHygiene('poo'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Add photo
                    _PhotoPicker(
                      photo: _photo,
                      onPick: _pickPhoto,
                      onClear: () {
                        setState(() => _photo = null);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Note
                    Text(
                      'NOTE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.muted,
                        letterSpacing: 0.6,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Walk note...',
                        hintStyle: TextStyle(
                          color: colors.muted,
                          fontFamily: 'PlusJakartaSans',
                        ),
                        filled: true,
                        fillColor: colors.card,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.coral),
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
                                backgroundColor: colors.softCard,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: Text(
                                _isPaused ? 'Resume' : 'Pause',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colors.ink,
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
                                backgroundColor: colors.coral,
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
    final colors = VitailColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colors.softCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.muted,
              letterSpacing: 0.6,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.ink,
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
    final colors = VitailColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? colors.coral : colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? colors.coral : colors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : colors.ink,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onPick,
    required this.onClear,
  });

  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = VitailColors.of(context);
    if (photo == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPick,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: colors.softCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              '+ Add photo',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.muted,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            File(photo!.path),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const VitailIcon('x', color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
