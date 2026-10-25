import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef WalkingRouteDistanceEstimator =
    Future<double?> Function(LatLng origin, LatLng destination);

Future<double?> estimateWalkingRouteDistance(
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
  final distanceMeters = (data['distanceMeters'] as num).toDouble();
  if (!distanceMeters.isFinite || distanceMeters < 0) {
    throw StateError('Walking route service returned an invalid distance.');
  }
  return distanceMeters;
}

String walkingRouteDistanceLabel(double? meters, {bool estimating = false}) {
  if (meters == null) {
    return estimating ? 'Calculating route…' : 'Route distance unavailable';
  }
  if (meters < 1000) return '${meters.round()} m by route';
  return '${(meters / 1000).toStringAsFixed(1)} km by route';
}
