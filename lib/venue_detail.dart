import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';


import 'rewards_screen.dart';

class VenueInfo {
  const VenueInfo({
    required this.partnerId,
    required this.name,
    required this.closingTime,
    required this.location,
    required this.details,
  });

  factory VenueInfo.fromJson(Map<String, dynamic> row) => VenueInfo(
    partnerId: row['partner_id']?.toString() ?? '',
    name: row['venue_name']?.toString() ?? 'Venue',
    closingTime: row['closing_time']?.toString(),
    location: _parseCoordinates(row['coordinates']),
    details: row['venue_details']?.toString() ?? '',
  );

  final String partnerId;
  final String name;
  final String? closingTime;
  final LatLng? location;
  final String details;

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

  String distanceLabelFrom(LatLng? userLocation) {
    final venueLocation = location;
    if (userLocation == null || venueLocation == null) {
      return 'Distance unavailable';
    }

    final meters = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      venueLocation.latitude,
      venueLocation.longitude,
    );

    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  static LatLng? _parseCoordinates(dynamic raw) {
    if (raw == null) return null;

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final nestedCoordinates = map['coordinates'];
      if (nestedCoordinates is List && nestedCoordinates.length >= 2) {
        return _geoJsonPoint(nestedCoordinates);
      }

      final latitude = map['latitude'] ?? map['lat'];
      final longitude = map['longitude'] ?? map['lng'] ?? map['lon'];
      if (latitude is num && longitude is num) {
        return LatLng(latitude.toDouble(), longitude.toDouble());
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
        return null;
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
        return LatLng(latitude, longitude);
      }
    }

    // Also accept a plain "latitude,longitude" string.
    final values = value.split(',');
    if (values.length == 2) {
      final latitude = double.tryParse(values[0].trim());
      final longitude = double.tryParse(values[1].trim());
      if (latitude != null && longitude != null) {
        return LatLng(latitude, longitude);
      }
    }

    return null;
  }

  static LatLng? _geoJsonPoint(List coordinates) {
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (latitude is! num || longitude is! num) return null;
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }
}

class VenueDetailScreen extends StatelessWidget {
  const VenueDetailScreen({
    super.key,
    required this.venue,
    required this.userLocation,
    required this.onStartWalk,
  });

  final VenueInfo venue;
  final LatLng? userLocation;
  final VoidCallback onStartWalk;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? const Color(0xFF242321) : Colors.white;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 320 + MediaQuery.paddingOf(context).top,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: dark
                        ? const Color(0xFF39443F)
                        : const Color(0xFFD6E7E1),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 12,
                    left: 20,
                    child: Material(
                      color: cardColor,
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.chevron_left, color: colors.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  venue.name,
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 22),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RewardsScreen(
                            partnerId: venue.partnerId,
                            venueName: venue.name,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.tertiary,
                      foregroundColor: const Color(0xFF241C24),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Text('CHECK REWARDS'),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: dark ? colors.outline : const Color(0xFFDEDAD4),
                      width: 1.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _VenueInfoColumn(
                            label: 'OPEN',
                            value: venue.hoursLabel,
                          ),
                        ),
                        VerticalDivider(
                          width: 28,
                          thickness: 1,
                          color: dark ? colors.outline : const Color(0xFFDEDAD4),
                        ),
                        Expanded(
                          child: _VenueInfoColumn(
                            label: 'DISTANCE',
                            value: venue.distanceLabelFrom(userLocation),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  'About this venue',
                  style: TextStyle(
                    fontSize: 22,
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
                    fontSize: 17,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: SizedBox(
          height: 60,
          child: FilledButton(
            onPressed: onStartWalk,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text('Start walk to ${venue.name}'),
          ),
        ),
      ),
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
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}