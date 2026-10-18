import 'vitail_icon.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reward_flow.dart';
import 'reward_venues.dart';
import 'rewards_data.dart';
// import 'dog_sharing.dart';
import 'exercise_data.dart';
import 'venue_walk.dart';
import 'detail_image_header.dart';
import 'vitail_snack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef WalkingRouteDistanceEstimator =
    Future<double?> Function(LatLng origin, LatLng destination);

/// One row of the `partnered_venues` table.
///
/// Reads: partner_id, venue_name, closing_time, venue_details, and the
/// location from EITHER numeric `latitude` + `longitude` columns (preferred)
/// OR the older text `coordinates` column. Missing columns are fine — they
/// just come through as null.
class VenueInfo {
  const VenueInfo({
    required this.partnerId,
    required this.name,
    required this.closingTime,
    required this.location,
    required this.details,
    this.photoUrl,
    this.venueType,
  });

  factory VenueInfo.fromJson(Map<String, dynamic> row) => VenueInfo(
    partnerId: row['partner_id']?.toString() ?? '',
    name: row['venue_name']?.toString() ?? 'Venue',
    closingTime: row['closing_time']?.toString(),
    location: _locationFromRow(row),
    details: row['venue_details']?.toString() ?? '',
    photoUrl: _asPhotoUrl(row['photo_url']),
    venueType: row['venue_type']?.toString(),
  );

  final String partnerId;
  final String name;
  final String? closingTime;
  final LatLng? location;
  final String details;

  /// 'vet' | 'park' | 'other' — null when the row predates the column
  /// (treated as 'other').
  final String? venueType;

  bool get isVet => venueType == 'vet';
  bool get isPark => venueType == 'park';

  /// Venue photo (`photo_url` column, text). Null when empty or not a web URL.
  final String? photoUrl;

  String get hoursLabel {
    final value = closingTime?.trim();
    if (value == null || value.isEmpty) return 'Hours not provided';

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return 'Closes $value';

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return 'Closes $value';
    }

    final time = DateFormat('h:mma').format(DateTime(2020, 1, 1, hour, minute));
    return 'Closes ${time.toLowerCase()}';
  }

  /// Straight-line distance in metres, or null if either point is unknown.
  double? distanceMetersFrom(LatLng? userLocation) {
    final venueLocation = location;
    if (userLocation == null || venueLocation == null) return null;
    return Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      venueLocation.latitude,
      venueLocation.longitude,
    );
  }

  String distanceLabelFrom(LatLng? userLocation) {
    final meters = distanceMetersFrom(userLocation);
    if (meters == null) return 'Distance unavailable';

    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  // --- Parsing helpers --------------------------------------------------------

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// Only full http(s) URLs are usable by Image.network; anything else
  /// (blank, a bare storage path, junk) is treated as "no photo".
  static String? _asPhotoUrl(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final isWebUrl =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    return isWebUrl ? text : null;
  }

  /// Null for values that can't be real coordinates (e.g. swapped or junk).
  static LatLng? _validLatLng(double latitude, double longitude) {
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    return LatLng(latitude, longitude);
  }

  /// Prefers the numeric latitude/longitude columns, then falls back to the
  /// text `coordinates` column, so either schema works.
  static LatLng? _locationFromRow(Map<String, dynamic> row) {
    final latitude = _asDouble(row['latitude']);
    final longitude = _asDouble(row['longitude']);
    if (latitude != null && longitude != null) {
      return _validLatLng(latitude, longitude);
    }
    return _parseCoordinates(row['coordinates']);
  }

  /// Understands: GeoJSON-style maps/lists (longitude first), {lat, lng} maps,
  /// JSON text, "POINT(lng lat)", and plain text pairs such as
  /// "-37.8136, 144.9631", "-37.8136 144.9631" or "(-37.8136, 144.9631)".
  static LatLng? _parseCoordinates(dynamic raw) {
    if (raw == null) return null;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final nestedCoordinates = map['coordinates'];
      if (nestedCoordinates is List && nestedCoordinates.length >= 2) {
        return _geoJsonPoint(nestedCoordinates);
      }

      final latitude = _asDouble(map['latitude'] ?? map['lat']);
      final longitude = _asDouble(map['longitude'] ?? map['lng'] ?? map['lon']);
      if (latitude != null && longitude != null) {
        return _validLatLng(latitude, longitude);
      }
      return null;
    }

    if (raw is List && raw.length >= 2) return _geoJsonPoint(raw);

    if (raw is! String) return null;
    final value = raw.trim();

    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        return _parseCoordinates(jsonDecode(value));
      } catch (_) {
        // Not JSON after all — fall through to the plain-text patterns.
      }
    }

    // PostGIS point text uses longitude first: POINT(longitude latitude).
    final point = RegExp(
      r'^POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (point != null) {
      final longitude = double.tryParse(point.group(1)!);
      final latitude = double.tryParse(point.group(2)!);
      if (latitude != null && longitude != null) {
        return _validLatLng(latitude, longitude);
      }
    }

    // Plain text pair. Latitude is assumed first; if the first number can't
    // be a latitude (|x| > 90) the pair is read as "longitude, latitude".
    final pair = RegExp(
      r'^[\(\[]?\s*(-?\d+(?:\.\d+)?)\s*[,;\s]\s*(-?\d+(?:\.\d+)?)\s*[\)\]]?$',
    ).firstMatch(value);
    if (pair != null) {
      final first = double.tryParse(pair.group(1)!);
      final second = double.tryParse(pair.group(2)!);
      if (first != null && second != null) {
        return first.abs() > 90
            ? _validLatLng(second, first)
            : _validLatLng(first, second);
      }
    }

    return null;
  }

  static LatLng? _geoJsonPoint(List coordinates) {
    final longitude = _asDouble(coordinates[0]);
    final latitude = _asDouble(coordinates[1]);
    if (latitude == null || longitude == null) return null;
    return _validLatLng(latitude, longitude);
  }
}

class VenueDetailScreen extends StatefulWidget {
  const VenueDetailScreen({
    super.key,
    required this.venue,
    this.userLocation,
    this.onStartWalk,
    this.onCheckRewards,
    this.rewardsRepository,
    this.venueLoader = loadRewardVenues,
    this.routeDistanceEstimator,
  });

  final RewardsRepository? rewardsRepository;
  final Future<List<VenueInfo>> Function() venueLoader;
  final VoidCallback? onCheckRewards;
  final VenueInfo venue;
  final Future<double?> Function()? dailyGoalKmLoader;

  /// The user's position if the caller already has it. If null, this screen
  /// looks it up itself so the distance still fills in.
  final LatLng? userLocation;

  /// Optional override for the destination walk.
  final Future<void> Function()? onStartWalk;
  final WalkingRouteDistanceEstimator? routeDistanceEstimator;

  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  LatLng? _userLocation;
  bool _locating = false;
  bool _startingWalk = false;
  bool _loadingReward = false;
  bool _estimatingRoute = false;
  bool _routeEstimateUnavailable = false;
  double? _routeDistanceMeters;
  int _routeRequestId = 0;

  Future<void> _checkRewards() async {
    if (_loadingReward) return;
    setState(() => _loadingReward = true);
    try {
      final repository =
          widget.rewardsRepository ?? SupabaseRewardsRepository();
      final catalogue = await repository.loadCatalogue();
      final venues = await widget.venueLoader();
      final offers =
          catalogue.offers.where((offer) {
            final linked = venueForReward(offer, venues);
            return linked != null &&
                linked.partnerId == widget.venue.partnerId &&
                linked.name == widget.venue.name;
          }).toList()..sort((a, b) {
            final cost = a.pointsCost.compareTo(b.pointsCost);
            return cost != 0 ? cost : a.id.compareTo(b.id);
          });
      if (!mounted) return;
      if (offers.isEmpty) {
        showVitailSnack(
          context,
          'No rewards are available for this venue yet.',
          type: VitailSnackType.info,
        );
        return;
      }
      final offer = offers.first;
      final receipts = await repository.loadRedeemed();
      if (!mounted) return;
      final receipt = receipts
          .where((reward) => reward.rewardId == offer.id && !reward.isCollected)
          .firstOrNull;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => RewardFlow(
            offer: offer,
            repository: repository,
            catalogue: catalogue,
            receipts: receipts,
            canRedeem: catalogue.points >= offer.pointsCost,
            redemption: receipt,
            venueLoader: widget.venueLoader,
            onChanged: (_) {},
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        showVitailSnack(
          context,
          'Could not load rewards. Please try CHECK REWARDS again.',
          type: VitailSnackType.error,
        );
    }} finally {
      if (mounted) setState(() => _loadingReward = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _userLocation = widget.userLocation;
    _loadDailyWalkGoal();
    if (_userLocation == null) {
      _locating = true;
      _locateUser();
    } else {
      _estimateWalkingRoute(_userLocation!);
    }
  }

  @override
  void didUpdateWidget(covariant VenueDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeInputsChanged =
        oldWidget.venue.location != widget.venue.location ||
        oldWidget.userLocation != widget.userLocation ||
        oldWidget.routeDistanceEstimator != widget.routeDistanceEstimator;
    if (!routeInputsChanged) return;

    _userLocation = widget.userLocation ?? _userLocation;
    final origin = _userLocation;
    if (origin != null) _estimateWalkingRoute(origin);
  }

  Future<void> _estimateWalkingRoute(LatLng origin) async {
    final destination = widget.venue.location;
    if (destination == null) return;

    final requestId = ++_routeRequestId;
    if (mounted) {
      setState(() {
        _estimatingRoute = true;
        _routeEstimateUnavailable = false;
        _routeDistanceMeters = null;
      });
    }

    try {
      final distanceMeters = widget.routeDistanceEstimator != null
          ? await widget.routeDistanceEstimator!(origin, destination)
          : await _requestWalkingRoute(origin, destination);
      if (distanceMeters == null ||
          !distanceMeters.isFinite ||
          distanceMeters < 0) {
        throw const FormatException('Walking route distance is unavailable.');
      }
      if (!mounted || requestId != _routeRequestId) return;
      setState(() => _routeDistanceMeters = distanceMeters);
    } catch (error) {
      debugPrint('Could not estimate walking route: $error');
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeEstimateUnavailable = true;
        _routeDistanceMeters = null;
      });
    } finally {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _estimatingRoute = false);
      }
    }
  }

  Future<double?> _requestWalkingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      'estimate-walking-route',
      body: {
        'origin': {'latitude': origin.latitude, 'longitude': origin.longitude},
        'destination': {
          'latitude': destination.latitude,
          'longitude': destination.longitude,
        },
      },
    );
    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map ||
        data['distanceMeters'] is! num) {
      throw StateError('Walking route service returned an invalid response.');
    }
    return (data['distanceMeters'] as num).toDouble();
  }

  Future<void> _locateUser() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

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
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _userLocation = location);
      await _estimateWalkingRoute(location);
    } catch (_) {
      // The distance simply stays unavailable.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _startWalk() async {
    final location = widget.venue.location;
    if (location == null || _startingWalk) return;
    final onStartWalk =
        widget.onStartWalk ?? () => startVenueWalk(context, location);
    setState(() => _startingWalk = true);
    try {
      await onStartWalk();
    } finally {
      if (mounted) setState(() => _startingWalk = false);
    }
  }

  String get _distanceLabel {
    final meters = _routeDistanceMeters;
    if (meters == null) {
      if (_estimatingRoute) return 'Calculating route…';
      return 'Route distance unavailable';
    }
    if (meters < 1000) return '${meters.round()} m by route';
    return '${(meters / 1000).toStringAsFixed(1)} km by route';
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? const Color(0xFF242321) : Colors.white;
    final points = _routeDistanceMeters == null
        ? null
        : ExerciseCalculator.pointsForDistanceMeters(_routeDistanceMeters!);

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Existing header: sizes the area and is what shows while the
                // photo loads, if it fails, or if the venue has no photo.
                const DetailImageHeader(),
                if (venue.photoUrl != null)
                  Positioned.fill(child: _VenuePhoto(url: venue.photoUrl!)),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  venue.name,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _loadingReward
                        ? null
                        : widget.onCheckRewards ?? _checkRewards,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: dark ? colors.outline : const Color(0xFFDBD7D1),
                        width: 1.5,
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: colors.tertiary,
                      foregroundColor: const Color(0xFF241C24),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      _loadingReward ? 'LOADING REWARD…' : 'CHECK REWARDS',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        points == null
                            ? (_estimatingRoute
                                  ? 'Calculating route points…'
                                  : 'Route points unavailable')
                            : '+ ${NumberFormat.decimalPattern('en').format(points)} pts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        points != null
                            ? 'Estimated from a walking route to this venue; actual points may vary.'
                            : _estimatingRoute
                            ? 'Estimating points from a walking route.'
                            : _routeEstimateUnavailable
                            ? 'Walking route could not be estimated.'
                            : _locating
                            ? 'Locating you to estimate the walking route.'
                            : venue.location == null
                            ? 'This venue location is unavailable.'
                            : 'Enable location to estimate route points for this venue.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dark ? colors.outline : const Color(0xFFDBD7D1),
                      width: 1.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _VenueInfoColumn(
                            label: 'HOURS',
                            value: venue.hoursLabel,
                          ),
                        ),
                        VerticalDivider(
                          width: 28,
                          thickness: 1,
                          color: dark
                              ? colors.outline
                              : const Color(0xFFDBD7D1),
                        ),
                        Expanded(
                          child: _VenueInfoColumn(
                            label: 'DISTANCE',
                            value: _distanceLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ABOUT THIS VENUE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  venue.details.trim().isEmpty
                      ? 'Details for this venue are not available yet.'
                      : venue.details.trim(),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (!_loadingDailyGoal) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          points == null
                              ? 'Walk goal unavailable'
                              : '+ ${NumberFormat.decimalPattern('en').format(points)} pts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          points == null
                              ? 'Set a daily walk goal to estimate points.'
                              : 'Estimated from your daily walk goal.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.venue.location == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: FilledButton(
                  onPressed: _startingWalk ? null : _startWalk,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.primary.withValues(
                      alpha: 0.6,
                    ),
                    disabledForegroundColor: colors.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _startingWalk
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Start walk to ${venue.name}',
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
            ),
    );
  }
}

/// Full-bleed venue photo drawn over the header. Invisible until it has
/// loaded (and stays invisible on error), so the placeholder header underneath
/// is what the user sees in those cases. Carries its own back button because
/// the photo covers the header's.
class _VenuePhoto extends StatelessWidget {
  const _VenuePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final backButton = Positioned(
      top: MediaQuery.paddingOf(context).top,
      left: 8,
      child: Material(
        color: dark ? const Color(0xFF242321) : Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: VitailIcon('chevron-left', color: colors.onSurface),
        ),
      ),
    );

    return Image.network(
      url,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final loaded = wasSynchronouslyLoaded || frame != null;
        return AnimatedOpacity(
          opacity: loaded ? 1 : 0,
          duration: wasSynchronouslyLoaded
              ? Duration.zero
              : const Duration(milliseconds: 300),
          child: Stack(fit: StackFit.expand, children: [child, backButton]),
        );
      },
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _VenueInfoColumn extends StatelessWidget {
  const _VenueInfoColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}
