import 'vitail_loading.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Design tokens from the Figma spec for this screen. Hardcoded because the
// app's ColorScheme doesn't define secondaryContainer / surfaceContainerHighest,
// so reading them from the theme silently falls back to Material's default
// purple tints (the "blended" colours after the merge). Fixed light design,
// matching walk_in_progress / onboarding / edit profile.
// ---------------------------------------------------------------------------
const Color _kPageBg = Color(0xFFF4F0E9); // Page background
const Color _kCard = Colors.white; // Stat cards + hygiene rows (with shadow)
const Color _kSoftCard = Color(0xFFF9F7F3); // "+ Add photo" button
const Color _kInk = Color(0xFF211F1D); // Primary text
const Color _kMuted = Color(0xFF6E6A63); // Secondary text
const Color _kBorder = Color(0xFFDBD7D1); // Field/chip borders
const Color _kAvatarBg = Color(0xFFE5E1DB); // Dog avatar placeholder
const Color _kRoutePlaceholder = Color(0xFFD1E8E1); // "Route map" placeholder
const Color _kGreenPale = Color(0xFFEAF0D8); // Points pill, star circle, active hygiene
const Color _kGreen = Color(0xFFAEC568); // Star icon, pill text, active hygiene text
const Color _kBlue = Color(0xFF5F98BD); // Selected mood chip
const Color _kCoral = Color(0xFFDC755C); // Done button, focus border, polyline

const List<BoxShadow> _kCardShadow = [
  BoxShadow(
    color: Color(0x0F000000), // 6% black, matches the Figma drop shadow
    blurRadius: 10,
    offset: Offset(0, 3),
  ),
];

class WalkSummary extends StatefulWidget {
  const WalkSummary({
    super.key,
    required this.distanceMeters,
    required this.elapsedSeconds,
    required this.goalMinutes,
    required this.dog,
    required this.hygiene,
    required this.routePoints,
    this.photo,
    this.initialNote,
  });

  final double distanceMeters;
  final int elapsedSeconds;
  final int goalMinutes;
  final Map<String, dynamic>? dog;

  // {'pee': bool, 'poo': bool}, as tracked during the walk.
  final Map<String, bool> hygiene;

  final List<LatLng> routePoints;

  // Carried over from WalkInProgress if the user already picked a photo or
  // typed a note mid-walk, so neither is lost when they land here.
  final XFile? photo;
  final String? initialNote;

  @override
  State<WalkSummary> createState() => _WalkSummaryState();
}

class _WalkSummaryState extends State<WalkSummary> {
  static const List<String> _moods = [
    'Active',
    'Playful',
    'Lazy',
    'Relaxing',
    'Adventure',
    'Training',
    'Social',
  ];

  String? _selectedMood;
  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialNote ?? '');
  late XFile? _photo = widget.photo;
  bool _isSaving = false;
  int? _pointsPreview;

  // Local, editable copy of the hygiene log, in case the user wants to
  // correct something before saving.
  late final Map<String, bool> _hygiene;

  @override
  void initState() {
    super.initState();
    _hygiene = Map<String, bool>.from(widget.hygiene);
    _computePointsPreview();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _baseDistancePoints => (widget.distanceMeters / 100).floor();

  Future<void> _computePointsPreview() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _pointsPreview = _baseDistancePoints);
        return;
      }

      int bonus = 0;
      if (widget.distanceMeters >= 1000) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final taskCheck = await Supabase.instance.client
            .from('daily_tasks')
            .select('walk_done')
            .eq('user_id', userId)
            .eq('task_date', today)
            .maybeSingle();

        if (taskCheck?['walk_done'] != true) bonus = 50;
      }

      if (mounted) {
        setState(() => _pointsPreview = _baseDistancePoints + bonus);
      }
    } catch (_) {
      // If we can't reach the quest table, still show the base points
      // rather than leaving the pill blank.
      if (mounted) setState(() => _pointsPreview = _baseDistancePoints);
    }
  }

  String get _formattedDistance =>
      (widget.distanceMeters / 1000).toStringAsFixed(2);

  String get _formattedTime {
    final minutes = (widget.elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (widget.elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _goalMet => widget.elapsedSeconds >= widget.goalMinutes * 60;

  String get _headline {
    if (_goalMet) return "Nice loop — that's the goal done.";
    final elapsedMinutes = widget.elapsedSeconds ~/ 60;
    final remaining = (widget.goalMinutes - elapsedMinutes).clamp(1, widget.goalMinutes);
    return 'Great walk! $remaining min short of today\'s goal.';
  }

  String get _hygieneStatus {
    final doneCount =
        (_hygiene['pee'] == true ? 1 : 0) + (_hygiene['poo'] == true ? 1 : 0);
    if (doneCount == 2) return 'Done';
    if (doneCount == 1) return 'Done 1/2';
    return 'Not yet';
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

  Future<void> _finishAndSave() async {
    if (_isSaving) return;

    // The timer never started (e.g. location permission was denied).
    // Discard instead of saving a 0-second walk.
    if (widget.elapsedSeconds < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk not started — nothing to save.')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    setState(() => _isSaving = true);

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isSaving = false);
      return;
    }

    final now = DateTime.now();
    final todayStr =
        DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

    // Single dog per user, attributed via dog_id.
    final String? dogId = widget.dog?['id']?.toString();

    // GPS trace for the route_data jsonb column.
    final routeData = [
      for (final p in widget.routePoints)
        {'lat': p.latitude, 'lng': p.longitude},
    ];

    // NOTE: 'p_mood', 'p_note', and 'p_photo_url' below assume the
    // save_walk() Postgres function has matching parameters (and that the
    // walks table has mood/note/photo_url columns for it to write into).
    // If it doesn't yet, this call will fail with a Postgrest "function
    // not found" error naming the mismatched signature — add the params
    // to save_walk() (or drop them from this call) accordingly.

    try {
      // Upload the photo first (if any) so we have a URL to store with the walk.
      String? photoUrl;
      if (_photo != null) {
        final fileName = '${userId}_walk_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage.from('walk_photos').upload(fileName, File(_photo!.path));
        photoUrl = client.storage.from('walk_photos').getPublicUrl(fileName);
      }
      // One atomic RPC: inserts the walk (with route + dog), computes the
      // points, marks the daily task and updates the streak — all
      // server-side, so none of it can be spoofed or race itself.
      await client.rpc('save_walk', params: {
        'p_distance_meters': widget.distanceMeters,
        'p_duration_seconds': widget.elapsedSeconds,
        'p_walk_date': todayStr,
        'p_dog_id': dogId,
        'p_route_data': routeData.isEmpty ? null : routeData,
        'p_hygiene_pee': _hygiene['pee'],
        'p_hygiene_poo': _hygiene['poo'],
        'p_mood': _selectedMood,
        'p_note': _noteController.text.trim(),
        'p_photo_url': photoUrl,
      });

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save walk: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Center(
              child: Text(
                'WALK SUMMARY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: _kMuted,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
            const SizedBox(height: 20),

            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _kGreenPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: _kGreen, size: 30),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kInk,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 24),

            // Distance / Time
            Row(
              children: [
                Expanded(
                  child: _StatCard(label: 'DISTANCE', value: '$_formattedDistance km'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(label: 'TIME', value: _formattedTime),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Points pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _kGreenPale,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _pointsPreview == null
                      ? 'Calculating points…'
                      : '+$_pointsPreview points earned',
                  style: const TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'HOW WAS THE WALK?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _kMuted,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _moods.map((mood) {
                final selected = _selectedMood == mood;
                return _MoodChip(
                  label: mood,
                  selected: selected,
                  onTap: () => setState(
                    () => _selectedMood = selected ? null : mood,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            const Text(
              'ROUTE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _kMuted,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 12),
            _RouteMapPreview(points: widget.routePoints),
            const SizedBox(height: 28),

            if (widget.dog != null) ...[
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'HYGIENE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _kMuted,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'PEE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _kMuted,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'POO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _kMuted,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Builder(builder: (context) {
                final name = widget.dog!['dog_name'] ?? 'Dog';
                final photoUrl = widget.dog!['photo_url'];
                final peeDone = _hygiene['pee'] ?? false;
                final pooDone = _hygiene['poo'] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _kCardShadow,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _kAvatarBg,
                        backgroundImage:
                            photoUrl != null && photoUrl.toString().isNotEmpty
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
                                  fontFamily: 'PlusJakartaSans'),
                            ),
                            Text(
                              _hygieneStatus,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: _kMuted,
                                  fontFamily: 'PlusJakartaSans'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: _HygieneButton(
                          label: 'PEE',
                          active: peeDone,
                          onTap: () => _toggleHygiene('pee'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 60,
                        child: _HygieneButton(
                          label: 'POO',
                          active: pooDone,
                          onTap: () => _toggleHygiene('poo'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            const Text(
              'NOTE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _kMuted,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a walk note...',
                hintStyle: const TextStyle(
                    color: _kMuted, fontFamily: 'PlusJakartaSans'),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            const SizedBox(height: 16),

            _PhotoPicker(photo: _photo, onPick: _pickPhoto, onClear: () {
              setState(() => _photo = null);
            }),
            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finishAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kCoral,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kCoral.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: VitailLoading(),
                      )
                    : const Text(
                        'Done',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'PlusJakartaSans'),
                      ),
              ),
            ),
          ],
        ),
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
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _kCardShadow,
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

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kBlue : _kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _kInk,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
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
          color: active ? _kGreenPale : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _kGreenPale : _kBorder,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? _kGreen : _kInk,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
      ),
    );
  }
}

/// Shows the recorded route on a small non-interactive map, or a friendly
/// placeholder if no GPS points were captured during the walk.
class _RouteMapPreview extends StatefulWidget {
  const _RouteMapPreview({required this.points});

  final List<LatLng> points;

  @override
  State<_RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<_RouteMapPreview> {
  GoogleMapController? _controller;

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

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return _placeholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: widget.points.first, zoom: 15),
          polylines: {
            Polyline(
              polylineId: const PolylineId('summary_route'),
              points: widget.points,
              color: _kCoral,
              width: 5,
            ),
          },
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
          myLocationButtonEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            final bounds = _boundsFor(widget.points);
            // Give the map a beat to lay out before fitting bounds.
            Future.delayed(const Duration(milliseconds: 300), () {
              _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 36));
            });
          },
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kRoutePlaceholder,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
          const Center(
            child: Text(
              'Route map',
              style: TextStyle(
                color: _kMuted,
                fontWeight: FontWeight.w600,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          ),
        ],
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
    if (photo == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPick,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kSoftCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text(
              '+ Add photo',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _kMuted,
                  fontFamily: 'PlusJakartaSans'),
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
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}