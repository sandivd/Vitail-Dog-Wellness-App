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
      .order('role')
      .limit(1);
  if (rows.isEmpty) return null;
  final row = rows.first as Map<String, dynamic>;
  return DogShare(
    dog: row['dogs'] as Map<String, dynamic>,
    role: row['role'] as String,
  );
}