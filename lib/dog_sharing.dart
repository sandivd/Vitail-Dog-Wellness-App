import 'package:supabase_flutter/supabase_flutter.dart';

const bool kSharingBackendReady = true;

class DogShare {
  const DogShare({required this.dog, required this.role});

  final Map<String, dynamic> dog;
  final String role;
}

Future<String> shareCodeForDog(String dogId) async {
  if (!kSharingBackendReady) {
    return 'AUG-7F3K';
  }
  final result = await Supabase.instance.client
      .rpc('generate_share_code', params: {'p_dog_id': dogId});
  return result as String;
}

Future<DogShare> joinWithCode(String code) async {
  if (!kSharingBackendReady) {
    return const DogShare(dog: {'id': 'stub', 'dog_name': 'Milo'}, role: 'carer');
  }
  final result = await Supabase.instance.client
      .rpc('join_dog_with_code', params: {'p_code': code.trim().toUpperCase()});
  final row = (result as List).first as Map<String, dynamic>;
  return DogShare(dog: row, role: 'carer');
}

Future<String?> roleForDog(String dogId) async {
  if (!kSharingBackendReady) return null;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final row = await Supabase.instance.client
      .from('user_dogs')
      .select('role')
      .eq('user_id', userId)
      .eq('dog_id', dogId)
      .maybeSingle();
  return row?['role'] as String?;
}

Future<DogShare?> primaryDogForCurrentUser() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  if (!kSharingBackendReady) return null;
  final rows = await Supabase.instance.client
      .from('user_dogs')
      .select('role, dogs(*)')
      .eq('user_id', userId)
      .order('role', ascending: false)
      .limit(1);
  if (rows.isEmpty) return null;
  final row = rows.first as Map<String, dynamic>;
  return DogShare(
    dog: row['dogs'] as Map<String, dynamic>,
    role: row['role'] as String,
  );
}

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.dogName,
    required this.status,
    this.requesterName,
  });

  factory JoinRequest.fromRow(Map<String, dynamic> row) => JoinRequest(
        id: row['id'] as String,
        dogName: (row['dog_name'] as String?) ?? 'the dog',
        status: row['status'] as String,
        requesterName: row['requester_name'] as String?,
      );

  final String id;
  final String dogName;
  final String status;
  final String? requesterName;
}

class JoinCodeException implements Exception {
  const JoinCodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _joinErrorMessage(String raw) {
  if (raw.contains('invalid_code')) {
    return "That code doesn't match any dog. Check it with the owner.";
  }
  if (raw.contains('own_dog')) return "That's your own dog's code.";
  if (raw.contains('name_required')) {
    return 'Enter your name so the owner knows who you are.';
  }
  return 'Something went wrong. Please try again.';
}

Future<JoinRequest> requestDogAccess(String code, String name) async {
  final SupabaseClient client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    await client.auth.signInAnonymously();
  }
  try {
    final dynamic result = await client.rpc(
      'request_dog_access',
      params: {'p_code': code, 'p_name': name},
    );
    final Map<String, dynamic> row =
        (result as List).first as Map<String, dynamic>;
    return JoinRequest(
      id: row['request_id'] as String,
      dogName: (row['dog_name'] as String?) ?? 'the dog',
      status: row['request_status'] as String,
    );
  } on PostgrestException catch (e) {
    throw JoinCodeException(_joinErrorMessage(e.message));
  }
}

Future<String?> joinRequestStatus(String requestId) async {
  final Map<String, dynamic>? row = await Supabase.instance.client
      .from('dog_join_requests')
      .select('status')
      .eq('id', requestId)
      .maybeSingle();
  return row?['status'] as String?;
}

Future<JoinRequest?> latestJoinRequest() async {
  final SupabaseClient client = Supabase.instance.client;
  final String? userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final Map<String, dynamic>? row = await client
      .from('dog_join_requests')
      .select('id, dog_name, status, requester_name')
      .eq('requester_id', userId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return row == null ? null : JoinRequest.fromRow(row);
}

Future<List<JoinRequest>> pendingRequestsForMyDogs() async {
  final SupabaseClient client = Supabase.instance.client;
  final String? userId = client.auth.currentUser?.id;
  if (userId == null) return const <JoinRequest>[];
  final List<Map<String, dynamic>> rows = await client
      .from('dog_join_requests')
      .select('id, dog_name, status, requester_name')
      .eq('status', 'pending')
      .neq('requester_id', userId)
      .order('created_at');
  return rows.map(JoinRequest.fromRow).toList();
}

Future<void> decideJoinRequest(String requestId, {required bool approve}) async {
  await Supabase.instance.client.rpc(
    'decide_dog_join_request',
    params: {'p_request_id': requestId, 'p_approve': approve},
  );
}

Future<void> cancelJoinRequest(String requestId) async {
  await Supabase.instance.client
      .from('dog_join_requests')
      .delete()
      .eq('id', requestId);
}