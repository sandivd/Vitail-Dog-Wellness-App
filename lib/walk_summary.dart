import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalkSummary extends StatefulWidget {
  const WalkSummary({
    super.key,
    required this.distanceMeters,
    required this.elapsedSeconds,
    required this.goalMinutes,
    required this.dogs,
    required this.hygiene,
    required this.routePoints,
  });

  final double distanceMeters;
  final int elapsedSeconds;
  final int goalMinutes;
  final List<Map<String, dynamic>> dogs;

  // dogId -> {'pee': bool, 'poo': bool}, as tracked during the walk.
  final Map<String, Map<String, bool>> hygiene;

  final List<LatLng> routePoints;

  @override
  State<WalkSummary> createState() => _WalkSummaryState();
}

class _WalkSummaryState extends State<WalkSummary> {
  static const Color pageBg = Color(0xFFEFECE6);
  static const Color coral = Color(0xFFBA5A3A);
  static const Color ink = Color(0xFF1E1E1E);
  static const Color muted = Color(0xFF7C776E);
  static const Color goalGreen = Color(0xFFD9E4B0);
  static const Color goalGreenText = Color(0xFF5C6B3F);

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
  final TextEditingController _noteController = TextEditingController();
  XFile? _photo;
  bool _isSaving = false;
  int? _pointsPreview;

  // Local, editable copy of the hygiene log, in case the user wants to
  // correct something before saving.
  late final Map<String, Map<String, bool>> _hygiene;

  @override
  void initState() {
    super.initState();
    _hygiene = {
      for (final entry in widget.hygiene.entries)
        entry.key: Map<String, bool>.from(entry.value),
    };
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

  String _hygieneStatus(String dogId) {
    final entry = _hygiene[dogId];
    if (entry == null) return 'Not yet';
    final doneCount =
        (entry['pee'] == true ? 1 : 0) + (entry['poo'] == true ? 1 : 0);
    if (doneCount == 2) return 'Done';
    if (doneCount == 1) return 'Done 1/2';
    return 'Not yet';
  }

  void _toggleHygiene(String dogId, String type) {
    setState(() {
      _hygiene.putIfAbsent(dogId, () => {'pee': false, 'poo': false});
      _hygiene[dogId]![type] = !(_hygiene[dogId]![type] ?? false);
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
    setState(() => _isSaving = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isSaving = false);
      return;
    }

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final todayStr = todayDateOnly.toIso8601String().split('T')[0];

    try {
      // Upload the photo first (if any) so we have a URL to store with the walk.
      String? photoUrl;
      if (_photo != null) {
        final fileName =
            '${userId}_walk_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('walk_photos')
            .upload(fileName, File(_photo!.path));
        photoUrl =
            Supabase.instance.client.storage.from('walk_photos').getPublicUrl(fileName);
      }

      int pointsEarned = _baseDistancePoints;

      // Bonus quest points: first 1km+ walk of the day earns +50.
      bool questBonusApplied = false;
      if (widget.distanceMeters >= 1000) {
        final taskCheck = await Supabase.instance.client
            .from('daily_tasks')
            .select('walk_done')
            .eq('user_id', userId)
            .eq('task_date', todayStr)
            .maybeSingle();

        if (taskCheck?['walk_done'] != true) {
          pointsEarned += 50;
          questBonusApplied = true;
        }
      }

      // 1. Save the walk.
      // NOTE: 'mood', 'note', and 'photo_url' assume matching columns exist
      // on the 'walks' table (mood text, note text, photo_url text). Add
      // them in Supabase if they don't exist yet, or this insert will
      // surface a Postgrest error naming the missing column.
      await Supabase.instance.client.from('walks').insert({
        'user_id': userId,
        'walk_date': todayStr,
        'distance_meters': widget.distanceMeters,
        'duration_seconds': widget.elapsedSeconds,
        'points_earned': pointsEarned,
        // 'mood': _selectedMood,       no mood column in schema
        // 'note': _noteController.text.trim(),      no note column in schema
        // 'photo_url': photoUrl,      no photo column in schema
      });

      if (questBonusApplied) {
        await Supabase.instance.client.from('daily_tasks').upsert({
          'user_id': userId,
          'task_date': todayStr,
          'walk_done': true,
        }, onConflict: 'user_id, task_date');
      }

      // 2. Fetch current points, streak, and last walk date.
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('total_points, daily_streak, last_walk_date')
          .eq('id', userId)
          .single();

      int currentPoints = profileRes['total_points'] ?? 0;
      int currentStreak = profileRes['daily_streak'] ?? 0;
      String? lastWalkStr = profileRes['last_walk_date'];

      // 3. Calculate new streak.
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

      // 4. Update profile with new points, streak, and date.
      await Supabase.instance.client.from('profiles').update({
        'total_points': currentPoints + pointsEarned,
        'daily_streak': newStreak,
        'last_walk_date': todayStr,
      }).eq('id', userId);

      // NOTE: hygiene (pee/poo) entries aren't persisted anywhere yet —
      // there's no dog-hygiene table in the current schema. They're shown
      // here for the user's own review, but only the walk itself is saved.

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
      backgroundColor: pageBg,
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
                  color: muted,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: goalGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: goalGreenText, size: 30),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
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
                color: goalGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  _pointsPreview == null
                      ? 'Calculating points…'
                      : '+$_pointsPreview points earned',
                  style: const TextStyle(
                    color: goalGreenText,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
                color: muted,
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
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            _RouteMapPreview(points: widget.routePoints),
            const SizedBox(height: 28),

            if (widget.dogs.isNotEmpty) ...[
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'HYGIENE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: muted,
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
                        color: muted,
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
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...widget.dogs.map((dog) {
                final dogId = dog['id'].toString();
                final name = dog['dog_name'] ?? 'Dog';
                final photoUrl = dog['photo_url'];
                final peeDone = _hygiene[dogId]?['pee'] ?? false;
                final pooDone = _hygiene[dogId]?['poo'] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7E2D8)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFDDD8CC),
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
                                  fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            Text(
                              _hygieneStatus(dogId),
                              style: const TextStyle(fontSize: 12, color: muted),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: _HygieneButton(
                          label: 'PEE',
                          active: peeDone,
                          onTap: () => _toggleHygiene(dogId, 'pee'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 60,
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
              const SizedBox(height: 20),
            ],

            const Text(
              'NOTE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a walk note...',
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
                  borderSide: const BorderSide(color: coral),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _PhotoPicker(photo: _photo, onPick: _pickPhoto, onClear: () {
              setState(() => _photo = null);
            }),
            const SizedBox(height: 24),

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finishAndSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: coral,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: coral.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Done',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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

class _MoodChip extends StatelessWidget {
  const _MoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _selectedBg = Color(0xFF6D8CA3);
  static const Color _ink = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _selectedBg : const Color(0xFFE0DCD3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontWeight: FontWeight.w600,
            fontSize: 14,
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

  static const Color _activeBg = Color(0xFFD9E4B0);
  static const Color _activeText = Color(0xFF5C6B3F);
  static const Color _ink = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? _activeBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _activeBg : const Color(0xFFE0DCD3),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? _activeText : _ink,
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
      return _placeholder();
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
              color: const Color(0xFFBA5A3A),
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

  Widget _placeholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD3E3DA),
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
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
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
                color: Color(0xFF5C6B58),
                fontWeight: FontWeight.w600,
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
            color: const Color(0xFFF3F0EA),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text(
              '+ Add photo',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E)),
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
