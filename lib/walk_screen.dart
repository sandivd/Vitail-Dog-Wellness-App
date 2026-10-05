import 'vitail_icon.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'venue_detail.dart';
import 'walk_in_progress.dart';
import 'vitail_snack.dart';

enum _RouteMode { longest }

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key, this.onProgress});

  final WalkProgressCallback? onProgress;

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  static const LatLng _melbourne = LatLng(-37.8136, 144.9631);

  // Collapsed height of the draggable sheet, as a fraction of screen height.
  // Shared with the Start-walk overlay below so it always sits just above
  // the sheet's handle instead of being covered by it.
  static const double _sheetCollapsedSize = 0.14;

  // Average dog-walk pace, used only to estimate time for the placeholder
  // "route to pin" line below (see _polylines / _routeSummaryText).
  static const double _walkingSpeedMetersPerSecond = 1.3; // ~4.7 km/h

  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();

  _RouteMode _routeMode = _RouteMode.longest;

  LatLng? _currentPosition;
  LatLng? _droppedPin;

  bool _isStartingWalk = false;

  // Partner venues loaded from the Supabase 'partnered_venues' table.
  List<VenueInfo> _nearbyVenues = [];
  bool _loadingVenues = true;
  String? _venueError;

  /// Venues matching the search box, nearest first. Until the user's location
  /// is known (or for venues without coordinates) they fall back to A–Z.
  List<VenueInfo> get _visibleVenues {
    final query = _searchController.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? [..._nearbyVenues]
        : _nearbyVenues
              .where((venue) => venue.name.toLowerCase().contains(query))
              .toList();

    matches.sort((a, b) {
      final distanceA = a.distanceMetersFrom(_currentPosition);
      final distanceB = b.distanceMetersFrom(_currentPosition);
      if (distanceA != null && distanceB != null) {
        final byDistance = distanceA.compareTo(distanceB);
        if (byDistance != 0) return byDistance;
      } else if (distanceA != null) {
        return -1; // venues with a known distance come first
      } else if (distanceB != null) {
        return 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matches;
  }

  @override
  void initState() {
    super.initState();
    _locateUser();
    _fetchVenues();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchController.dispose();
    super.dispose();
    widget.onProgress?.call(null);
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

  Future<void> _fetchVenues() async {
    try {
      // select() with no column list = every column. VenueInfo.fromJson picks
      // out what it needs (incl. optional latitude/longitude/points), so this
      // keeps working before and after those columns are added.
      final rows = await Supabase.instance.client.from('partnered_venues').select();

      if (!mounted) return;
      setState(() {
        _nearbyVenues = rows
            .map((row) => VenueInfo.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        _venueError = null;
        _loadingVenues = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _venueError = 'Could not load nearby venues.';
        _loadingVenues = false;
      });
    }
  }
  void _retryVenues() {
    setState(() {
      _loadingVenues = true;
      _venueError = null;
    });
    _fetchVenues();
  }

  /// Opens that venue's own detail page. Its "Start walk to …" button comes
  /// back here so the walk can head for the venue's coordinates.
  void _openVenue(VenueInfo venue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueDetailScreen(
          venue: venue,
          userLocation: _currentPosition,
        ),
      ),
    );
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
    final location = matches.first.location;
    if (location != null) _dropPinAt(location);
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

  Future<void> _startWalk({LatLng? destination}) async {
    if (_isStartingWalk) return;
    setState(() => _isStartingWalk = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Single dog per user — fetch it directly instead of routing through
      // a dog-selection screen.
      final dog = await Supabase.instance.client
          .from('dogs')
          .select()
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (dog == null) {
        showVitailSnack(context, 'No dog found. Please register a dog first.',
            type: VitailSnackType.error);
        return;
      }

      final routeDestination = destination ?? _droppedPin;

      // GPS may not have resolved yet if the user tapped quickly. Wait for
      // it so the planned route isn't silently dropped.
      if (routeDestination != null && _currentPosition == null) {
        await _locateUser();
        if (!mounted) return;
      }

      final hasPlannedRoute =
          _currentPosition != null && routeDestination != null;

      if (routeDestination != null && !hasPlannedRoute) {
        showVitailSnack(
          context,
          'Couldn’t get your location, so the route won’t be shown.',
          type: VitailSnackType.info,
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WalkInProgress(
            dog: dog,
            plannedRoute: hasPlannedRoute
                ? [_currentPosition!, routeDestination!]
                : null,
            onProgress: widget.onProgress,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        showVitailSnack(context, 'Could not start the walk. Please try again.',
            type: VitailSnackType.error);
      }
    } finally {
      if (mounted) setState(() => _isStartingWalk = false);
    }
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

          // Top overlay: search bar and route mode toggle.
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
                            onChanged: (_) => setState(() {}),
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
                          child: VitailIcon('locate-fixed',
                              color: colorScheme.secondary, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Route mode toggle — one bar, selected side shown as a
                  // green pill.
                  _RouteModeToggle(
                    mode: _routeMode,
                    onChanged: (mode) => setState(() => _routeMode = mode),
                  ),
                ],
              ),
            ),
          ),

          // Summary pill + Start walk button: a fixed overlay above the
          // draggable sheet, not part of its scrollable content.
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.sizeOf(context).height * _sheetCollapsedSize + 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isStartingWalk ? null : _startWalk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      disabledBackgroundColor:
                          colorScheme.primary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isStartingWalk
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Start walk',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              VitailIcon('play', size: 24),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Draggable panel: nearby venues + start walk button.
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _sheetCollapsedSize,
            minChildSize: _sheetCollapsedSize,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [_sheetCollapsedSize, 0.5, 0.9],
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
                        // TextButton(
                        //   onPressed: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => const VenuesScreen(),
                        //       ),
                        //     );
                        //   },
                        //   style: TextButton.styleFrom(
                        //     padding: EdgeInsets.zero,
                        //     minimumSize: const Size(0, 0),
                        //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        //   ),
                        //   child: Text(
                        //     'See all',
                        //     style: TextStyle(
                        //       color: colorScheme.secondary,
                        //       fontWeight: FontWeight.w600,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_loadingVenues)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_venueError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Text(
                              _venueError!,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              onPressed: _retryVenues,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      )
                    else if (_visibleVenues.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No venues nearby',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._visibleVenues.map(
                        (venue) => _VenueCard(
                          name: venue.name,
                          subtitle: venue.distanceLabelFrom(_currentPosition),
                          tag: venue.hoursLabel,
                          tagColor: colorScheme.tertiary.withValues(alpha: 0.3),
                          photoUrl: venue.photoUrl,
                          onTap: () => _openVenue(venue),
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

/// Segmented bar for choosing between "Last route" and "Longest route" —
/// one pill-shaped container, with the selected side highlighted as a
/// solid green pill.
class _RouteModeToggle extends StatelessWidget {
  const _RouteModeToggle({required this.mode, required this.onChanged});

  final _RouteMode mode;
  final ValueChanged<_RouteMode> onChanged;

  // Matches the green used for mood chips / points pill elsewhere in the
  // app (see walk_summary.dart's _kGreen) — not in ColorScheme, so hardcoded
  // to stay consistent with those other hardcoded Figma tokens.
  static const Color _kGreen = Color(0xFFAEC568);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _RouteModeSegment extends StatelessWidget {
  const _RouteModeSegment({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
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
    this.photoUrl,
  });

  final String name;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  /// Venue photo; the grey square shows when null, loading, or on error.
  final String? photoUrl;

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
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl == null
                  ? null
                  : Image.network(
                      photoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      // Decode at thumbnail size, not full resolution.
                      cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).round(),
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 250),
                          child: child,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
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
            VitailIcon('chevron-right', color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}


// Command: E:\user\Android_Studio\SDK\platform-tools\adb.exe -s emulator-5554 shell am force-stop com.example.vitail
// Flutter: Installing build\app\outputs\flutter-apk\app-debug.apk...
