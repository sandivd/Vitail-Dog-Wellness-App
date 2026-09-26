import 'package:supabase_flutter/supabase_flutter.dart';

const bool kSharingBackendReady = false;

const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

enum DogRole { owner, carer }

class InvalidShareCodeException implements Exception {
  const InvalidShareCodeException([this.message = 'That code did not match any dog.']);
  final String message;

  @override
  String toString() => message;
}

class SharingBackendUnavailable implements Exception {
  const SharingBackendUnavailable();

  @override
  String toString() => 'Sharing tables are not set up in Supabase yet.';
}

class DogSharing {
  const DogSharing._();

  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _uid => _client.auth.currentUser?.id;

  static String? normaliseShareCode(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length != 7) return null;
    if (!RegExp('^[$_codeAlphabet]{7}\$').hasMatch(cleaned)) return null;
    return '${cleaned.substring(0, 3)}-${cleaned.substring(3)}';
  }

  static String shareLinkForCode(String code) =>
      'vitail.online/i/${code.replaceAll('-', '').toLowerCase()}';

  static Future<String> shareCodeForDog(String dogId) async {
    if (!kSharingBackendReady) return _stubCodeFor(dogId);

    final existing = await _client
        .from('dogs')
        .select('share_code')
        .eq('id', dogId)
        .maybeSingle();

    final String? current = existing?['share_code'] as String?;
    if (current != null && current.isNotEmpty) return current;

    final String generated =
        await _client.rpc('generate_share_code') as String;

    await _client
        .from('dogs')
        .update({'share_code': generated})
        .eq('id', dogId);

    return generated;
  }

  static Future<String> joinWithCode(String rawCode) async {
    final String? code = normaliseShareCode(rawCode);
    if (code == null) throw const InvalidShareCodeException();

    if (!kSharingBackendReady) return 'stub-dog-$code';

    try {
      final result =
          await _client.rpc('join_dog_with_code', params: {'p_code': code});
      if (result == null) throw const InvalidShareCodeException();
      return result.toString();
    } on PostgrestException catch (e) {
      if (e.message.contains('invalid_code')) {
        throw const InvalidShareCodeException();
      }
      rethrow;
    }
  }

  static Future<DogRole?> roleForDog(String dogId) async {
    if (!kSharingBackendReady) return DogRole.owner;

    final String? userId = _uid;
    if (userId == null) return null;

    final row = await _client
        .from('user_dogs')
        .select('role')
        .eq('user_id', userId)
        .eq('dog_id', dogId)
        .maybeSingle();

    final String? role = row?['role'] as String?;
    if (role == 'owner') return DogRole.owner;
    if (role == 'carer') return DogRole.carer;
    return null;
  }

  static Future<bool> isOwnerOf(String dogId) async =>
      (await roleForDog(dogId)) == DogRole.owner;

  static Future<Map<String, dynamic>?> primaryDogForCurrentUser() async {
    final String? userId = _uid;
    if (userId == null) return null;

    if (!kSharingBackendReady) {
      final rows = await _client
          .from('dogs')
          .select()
          .eq('owner_id', userId)
          .limit(1);
      final list = rows as List<dynamic>;
      return list.isEmpty ? null : list.first as Map<String, dynamic>;
    }

    final memberships = await _client
        .from('user_dogs')
        .select('dog_id, role, dogs(*)')
        .eq('user_id', userId)
        .order('created_at')
        .limit(1);

    final list = memberships as List<dynamic>;
    if (list.isEmpty) return null;

    final Map<String, dynamic> row = list.first as Map<String, dynamic>;
    final dog = row['dogs'];
    return dog is Map<String, dynamic> ? dog : null;
  }

  static Future<bool> hasAnyDog() async =>
      (await primaryDogForCurrentUser()) != null;

  static String _stubCodeFor(String dogId) {
    int seed = dogId.hashCode.abs();
    int next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed;
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 7; i++) {
      if (i == 3) buffer.write('-');
      buffer.write(_codeAlphabet[next() % _codeAlphabet.length]);
    }
    return buffer.toString();
  }
}