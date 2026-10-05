import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'walk_in_progress.dart';


/// Starts the existing walk tracker with the venue as its planned destination.
Future<void> startVenueWalk(BuildContext context, LatLng destination) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Please sign in to start a walk.');
    final dog = await client
        .from('dogs')
        .select()
        .eq('owner_id', userId)
        .limit(1)
        .maybeSingle();
    if (dog == null) throw StateError('Please register a dog first.');
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Please enable location services to walk to this venue.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is needed to walk to this venue.');
    }
    final position = await Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 20),
    );
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WalkInProgress(
          dog: dog,
          plannedRoute: [
            LatLng(position.latitude, position.longitude),
            destination,
          ],
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not start the walk. Check your connection, location permission and registered dog, then try again.',
        ),
      ),
    );
  }
}
