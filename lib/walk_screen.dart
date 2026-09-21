import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'walk_choose_dog_profiles.dart';
import 'venues_screen.dart';

enum _RouteMode { last, longest }

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  static const Color pageBg = Color(0xFFEFECE6);
  static const Color coral = Color(0xFFBA5A3A);
  static const Color muted = Color(0xFF7C776E);
  static const Color linkBlue = Color(0xFF3E6FB0);

  static const LatLng _melbourne = LatLng(-37.8136, 144.9631);

  // Average dog-walk pace, used only to estimate time for the placeholder
  // "route to pin" line below (see _polylines / _routeSummaryText).
  static const double _walkingSpeedMetersPerSecond = 1.3; // ~4.7 km/h

  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();

  _RouteMode _routeMode = _RouteMode.last;

  LatLng? _currentPosition;
  LatLng? _droppedPin;

  Map<String, dynamic>? _lastWalk;
  bool _loadingLastWalk = true;

  // Placeholder partner venues. Swap for a Supabase 'venues' query once
  // that table exists, keeping the same name/subtitle/tag/location shape.
  final List<Map<String, dynamic>> _nearbyVenues = const [
    {
      'name': 'Royal Park',
      'subtitle': 'Off-lead park · 400 m',
      'tag': 'Free entry',
      'tagColor': Color(0xFFD9E4B0),
      'location': LatLng(-37.7850, 144.9470),
    },
    {
      'name': 'The Grounds Café',
      'subtitle': 'Dog-friendly café · 650 m',
      'tag': 'Free coffee · 250 pts',
      'tagColor': Color(0xFFE7B9A6),
      'location': LatLng(-37.8110, 144.9600),
    },
    {
      'name': 'Paws Vet Clinic',
      'subtitle': 'Partner vet · 1.2 km',
      'tag': '15% off check-up',
      'tagColor': Color(0xFFB9D8CE),
      'location': LatLng(-37.8180, 144.9700),
    },
  ];

  List<Map<String, dynamic>> get _visibleVenues {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _nearbyVenues;
    return _nearbyVenues
        .where((v) => v['name'].toString().toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _locateUser();
    _fetchLastWalk();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    } catch (_) {
      // Keep the default camera position if location isn't available yet.
    }
  }

  Future<void> _fetchLastWalk() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loadingLastWalk = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('walks')
          .select('distance_meters, duration_seconds, walk_date')
          .eq('user_id', userId)
          .order('walk_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _lastWalk = response;
        _loadingLastWalk = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLastWalk = false);
    }
  }

  void _recenter() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition!));
    } else {
      _locateUser();
    }
  }

  void _dropPinAt(LatLng point) {
    setState(() {
      _droppedPin = point;
      _routeMode = _RouteMode.longest;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(point));
  }

  void _onSearchSubmitted(String query) {
    final matches = _visibleVenues;
    if (matches.isEmpty) return;
    _dropPinAt(matches.first['location'] as LatLng);
    FocusScope.of(context).unfocus();
  }

  Set<Polyline> _buildPolylines(Color lineColor) {
    if (_routeMode == _RouteMode.longest &&
        _currentPosition != null &&
        _droppedPin != null) {
      return {
        Polyline(
          polylineId: const PolylineId('pin_route'),
          points: [_currentPosition!, _droppedPin!],
          color: lineColor,
          width: 5,
          patterns: [PatternItem.dash(14), PatternItem.gap(10)],
        ),
      };
    }
    return {};
  }

  Set<Marker> get _markers {
    if (_droppedPin == null) return {};
    return {
      Marker(markerId: const MarkerId('dropped_pin'), position: _droppedPin!),
    };
  }

  String get _routeSummaryText {
    if (_routeMode == _RouteMode.last) {
      if (_loadingLastWalk) return '···';
      if (_lastWalk == null) return 'No past walks yet';
      final meters = (_lastWalk!['distance_meters'] as num).toDouble();
      final seconds = (_lastWalk!['duration_seconds'] as num?)?.toInt() ?? 0;
      return '${(meters / 1000).toStringAsFixed(1)} km · ${(seconds / 60).round()} min';
    }

    if (_currentPosition == null || _droppedPin == null) {
      return 'Search or drop a pin for a route';
    }
    final meters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _droppedPin!.latitude,
      _droppedPin!.longitude,
    );
    final minutes = (meters / _walkingSpeedMetersPerSecond / 60).round();
    return '${(meters / 1000).toStringAsFixed(1)} km · $minutes min';
  }

  void _startWalk() {
    // Carry the dropped-pin route forward if the user set one up — it'll
    // show on the map once tracking begins in WalkInProgress.
    final hasPlannedRoute = _currentPosition != null && _droppedPin != null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChooseDogProfiles(
          plannedRoute: hasPlannedRoute
              ? [_currentPosition!, _droppedPin!]
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Map fills the whole screen; overlays and the sheet sit on top.
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition:
                  const CameraPosition(target: _melbourne, zoom: 14.0),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _markers,
              polylines: _buildPolylines(colorScheme.primary),
              onLongPress: _dropPinAt,
            ),
          ),

          // Top overlay: search bar, route mode toggle, legend, summary pill.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: _onSearchSubmitted,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search parks, cafés, vets...',
                              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _recenter,
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.gps_fixed,
                              color: colorScheme.secondary, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Route mode toggle
                  Row(
                    children: [
                      _RoutePill(
                        label: 'Last route',
                        selected: _routeMode == _RouteMode.last,
                        onTap: () => setState(() => _routeMode = _RouteMode.last),
                      ),
                      const SizedBox(width: 16),
                      _RouteLink(
                        label: 'Longest route',
                        selected: _routeMode == _RouteMode.longest,
                        onTap: () =>
                            setState(() => _routeMode = _RouteMode.longest),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 10),
                  const SizedBox(height: 18),

                  // Distance / time summary pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      _routeSummaryText,
                      style: TextStyle(
                        color: colorScheme.surface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Draggable panel: nearby venues + start walk button.
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.5,
            minChildSize: 0.16,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.16, 0.5, 0.9],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NEARBY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VenuesScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_visibleVenues.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No matches nearby',
                              style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ),
                      )
                    else
                      ..._visibleVenues.map(
                        (venue) => _VenueCard(
                          name: venue['name'] as String,
                          subtitle: venue['subtitle'] as String,
                          tag: venue['tag'] as String,
                          tagColor: venue['tagColor'] as Color,
                          onTap: () => _dropPinAt(venue['location'] as LatLng),
                        ),
                      ),

                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _startWalk,
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: const Text(
                          'Start a walk',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                      ),
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

/// Filled pill used for the currently-selected route mode ("Last route").
class _RoutePill extends StatelessWidget {
  const _RoutePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Underlined text link style used for the non-selected route mode
/// ("Longest route"), matching the mockup's link-like second option.
class _RouteLink extends StatelessWidget {
  const _RouteLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            decoration:
                selected ? TextDecoration.underline : TextDecoration.none,
            decorationColor: colorScheme.secondary,
            decorationThickness: 2,
          ),
        ),
      ),
    );
  }
}



/// A single nearby-venue row: placeholder thumbnail, name/subtitle, tag pill,
/// and a chevron. Backed by placeholder data for now (see _nearbyVenues).
class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.name,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}