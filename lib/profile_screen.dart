import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_sharing.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'microchip_screen.dart';
import 'settings_screen.dart';
import 'vitail_loading.dart';
import 'vitail_snack.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dogData;
  bool _isLoading = true;

  int _dailyStreak = 0;
  int _totalWalks = 0;
  int _totalSeconds = 0;
  double _totalDistanceKm = 0.0;
  
  int _careScore = 0;
  Map<String, Map<String, dynamic>> _scoreComponents = {};

  // Design Tokens based on Figma
  static const Color _kPageBg = Color(0xFFF4F0E9);
  static const Color _kCoral = Color(0xFFDC755C);
  static const Color _kTealBg = Color(0xFFDCEFEA); 
  static const Color _kGreen = Color(0xFFAEC568);
  static const Color _kBadgeGreen = Color(0xFFE5EED4); // Soft pastel green
  static const Color _kBadgeInactive = Color(0xFFF5F4F0);
  static const Color _kInk = Color(0xFF211F1D);
  static const Color _kMuted = Color(0xFF6E6A63);
  static const Color _kCard = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final dogResponse = (await primaryDogForCurrentUser())?.dog ??
          await Supabase.instance.client
              .from('dogs')
              .select()
              .eq('owner_id', userId)
              .limit(1)
              .maybeSingle();

      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('daily_streak')
          .eq('id', userId)
          .single();

      final walksResponse = await Supabase.instance.client
          .from('walks')
          .select('distance_meters, walk_date, duration_seconds')
          .eq('user_id', userId);

      double totalDistanceMeters = 0;
      int totalSecs = 0;
      for (var walk in walksResponse) {
        totalDistanceMeters += (walk['distance_meters'] as num).toDouble();
        totalSecs += (walk['duration_seconds'] as num).toInt();
      }

      setState(() {
        _dogData = dogResponse;
        _dailyStreak = profileResponse['daily_streak'] ?? 0;
        _totalWalks = walksResponse.length;
        _totalSeconds = totalSecs;
        _totalDistanceKm = totalDistanceMeters / 1000;
        
        _calculateCareScore(List<Map<String, dynamic>>.from(walksResponse), dogResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateCareScore(List<Map<String, dynamic>> walks, Map<String, dynamic>? dog) {
    if (dog == null) return;

    DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    List recentWalks = walks.where((w) => DateTime.parse(w['walk_date']).isAfter(sevenDaysAgo)).toList();
    
    int activityScore = ((recentWalks.length * 100) / 7).round().clamp(0, 100);
    int vaccScore = dog['vaccination_status'] == 'up_to_date' ? 100 : 0;
    int microchipScore = dog['microchip_number'] != null ? 100 : 0;
    int insuranceScore = dog['insurance_status'] == 'active' ? 100 : 0;
    int vetScore = 0;
    
    if (dog['last_vet_checkup'] != null) {
      DateTime lastVet = DateTime.parse(dog['last_vet_checkup']);
      if (DateTime.now().difference(lastVet).inDays <= 180) {
        vetScore = 100;
      }
    }

    int totalScore = (activityScore * 0.40 + vaccScore * 0.20 + microchipScore * 0.15 + insuranceScore * 0.15 + vetScore * 0.10).round();

    final String microchipNum = dog['microchip_number']?.toString() ?? '';
    final String microchipStatus = microchipNum.isNotEmpty ? 'Linked · $microchipNum' : 'Not added';
    
    final String vaccDate = dog['vaccination_date']?.toString() ?? '';
    final String vaccStatus = vaccDate.isNotEmpty ? 'Up to date' : 'Unknown';
    
    final String insuranceName = dog['insurance_partner']?.toString() ?? '';
    final String insuranceStatus = insuranceName.isNotEmpty ? insuranceName : 'Not added';

    final String vetDate = dog['last_vet_checkup']?.toString() ?? '';
    final String vetStatus = vetDate.isNotEmpty ? 'Up to date' : 'Book your next visit';

    Map<String, Map<String, dynamic>> components = {
      'Activity (7 days)': {'score': activityScore, 'status': '${recentWalks.length}/7 days active'},
      'Vaccinations': {'score': vaccScore, 'status': vaccStatus},
      'Microchip': {'score': microchipScore, 'status': microchipStatus},
      'Insurance': {'score': insuranceScore, 'status': insuranceStatus},
      'Vet check-in': {'score': vetScore, 'status': vetStatus},
    };

    setState(() {
      _careScore = totalScore;
      _scoreComponents = components;
    });
  }

  String get _formattedTime {
    final hours = _totalSeconds ~/ 3600;
    final minutes = (_totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get _dogSubtitle {
    if (_dogData == null) return 'Setup your dog\'s profile';
    final breed = _dogData!['breed'] ?? 'Unknown Breed';
    final birthdayStr = _dogData!['birthday'];
    
    if (birthdayStr == null) return breed;
    
    final birthday = DateTime.tryParse(birthdayStr);
    if (birthday == null) return breed;

    final now = DateTime.now();
    int years = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      years--;
    }
    
    if (years <= 0) return 'Puppy $breed';
    return '$years year-old $breed';
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      showVitailSnack(context, 'Error logging out', type: VitailSnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _kPageBg,
        body: Center(child: VitailLoading()),
      );
    }

    final String dogName = _dogData?['dog_name'] ?? 'Your Dog';
    final String? photoUrl = _dogData?['photo_url'];

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Settings + Avatar
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                        _fetchProfile();
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: _kCoral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (context) => EditProfileScreen(dog: _dogData)),
                          );
                          if (changed == true) _fetchProfile();
                        },
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 64, 
                              backgroundColor: _kTealBg,
                              backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                              child: photoUrl == null ? const Icon(Icons.pets, size: 48, color: _kMuted) : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _kCoral,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _kPageBg, width: 3),
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        dogName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dogSubtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Streak Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kTealBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_outlined, color: _kInk, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '$_dailyStreak days streak!',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Stats Row
              Row(
                children: [
                  Expanded(child: _buildStatBox('$_totalWalks', 'WALKS')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatBox(_formattedTime, 'TIME')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatBox('${_totalDistanceKm.toStringAsFixed(1)} km', 'DISTANCE')),
                ],
              ),

              const SizedBox(height: 32),
              
              // Care Score Section
              const Text(
                'CARE SCORE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              
              // Main Score Ring
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: SizedBox(
                    width: 140, 
                    height: 140, 
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _careScore > 0 ? (_careScore / 100) : 1.0,
                          strokeWidth: 14,
                          color: _kGreen,
                          backgroundColor: _kTealBg,
                        ),
                        Center(
                          child: Text(
                            _careScore > 0 ? '$_careScore' : '- -',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: _kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Care Score Items
              ..._scoreComponents.entries.map((entry) => _buildMenuCard(
                title: entry.key,
                subtitle: entry.value['status'],
                onTap: () async {
                  if (entry.key == 'Microchip') {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MicrochipScreen(
                          isFromProfile: true,
                          dogId: _dogData?['id']?.toString(),
                          initialNumber: _dogData?['microchip_number']?.toString(),
                        ),
                      ),
                    );
                    if (updated == true) {
                      _fetchProfile();
                    }
                    return;
                  }
                  showVitailSnack(context, '${entry.key} settings coming soon', type: VitailSnackType.info);
                },
              )),

              const SizedBox(height: 24),
              
              // Badges Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BADGES',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.5),
                  ),
                  Text(
                    'See all',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kCoral),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBadge('First walk', _totalWalks >= 1),
                    _buildBadge('5 walks', _totalWalks >= 5),
                    _buildBadge('Park explorer', _totalDistanceKm >= 5.0),
                    _buildBadge('30 day streak', _dailyStreak >= 30),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Action Menu
              _buildMenuCard(title: 'Invite a carer', subtitle: null, onTap: () {
                showVitailSnack(context, 'Carer invites coming soon', type: VitailSnackType.info);
              }),
              _buildMenuCard(title: 'My coupons', subtitle: '2 available', onTap: () {
                 showVitailSnack(context, 'Coupons coming soon', type: VitailSnackType.info);
              }),
              _buildMenuCard(title: 'Wellness history', subtitle: 'Walks, vet, weight', onTap: () {
                showVitailSnack(context, 'Wellness history coming soon', type: VitailSnackType.info);
              }),
              _buildMenuCard(title: 'Notifications', subtitle: 'Reminders', onTap: () {
                 showVitailSnack(context, 'Notifications coming soon', type: VitailSnackType.info);
              }),
              _buildMenuCard(title: 'Rate the app', subtitle: null, onTap: () {
                 showVitailSnack(context, 'App rating coming soon', type: VitailSnackType.info);
              }),

              const SizedBox(height: 32),

              // Log out Button
              OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kCoral,
                  side: const BorderSide(color: _kCoral, width: 1.5),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 40),

              // Bottom Logo composed of individual images
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/brand/vitail-mark.png',
                    height: 58, 
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: _kCoral, size: 58),
                  ),
                  const SizedBox(width: 4),
                  Image.asset(
                    'assets/brand/vitail-title.png',
                    height: 36, 
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text('VITAIL', style: TextStyle(color: _kCoral, fontSize: 36, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _kTealBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kInk),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kMuted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, bool earned) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: earned ? _kBadgeGreen : _kBadgeInactive,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9, 
            fontWeight: FontWeight.w600, 
            color: earned ? _kInk : _kMuted,
          ),
        )
      ],
    );
  }

  Widget _buildMenuCard({required String title, required String? subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kInk)),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kMuted)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _kMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}