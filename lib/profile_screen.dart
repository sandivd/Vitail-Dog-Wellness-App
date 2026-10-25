import 'microchip_validation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'care_score_screen.dart';
import 'dog_sharing.dart';
import 'reward_image_placeholder.dart';
import 'rewards_data.dart';
import 'rewards_screen.dart';
import 'share_code_screen.dart';
import 'vitail_icon.dart';
import 'walk_history_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'microchip_screen.dart';
import 'settings_screen.dart';
import 'vitail_loading.dart';
import 'vitail_snack.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _dogData;
  bool _isLoading = true;
  int _profileRequest = 0;

  int _dailyStreak = 0;
  String? _dogRole;
  int? _availableCoupons;
  bool _microchipPending = false;
  
  int _careScore = 0;
  Map<String, Map<String, dynamic>> _scoreComponents = {};

  // Design tokens (Figma light values) + theme-aware getters for dark mode.
  // Light fills stay as constants; text/surface colors resolve from the
  // app ColorScheme so the screen follows Settings' dark-mode toggle.
  static const Color _kCoral = Color(0xFFDC755C);
  static const Color _kTealBgLight = Color(0xFFDCEFEA);
  static const Color _kGreen = Color(0xFFAEC568);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBg => Theme.of(context).colorScheme.surface;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _card => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _tealBg => _isDark ? const Color(0xFF2E3A44) : _kTealBgLight;
  Color get _tileBg =>
      _isDark ? const Color(0xFF282828) : const Color(0xFFF9F7F3);

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final request = ++_profileRequest;
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final link = await primaryDogForCurrentUser();
      final dogResponse = link?.dog ??
          await Supabase.instance.client
              .from('dogs')
              .select()
              .eq('owner_id', userId)
              .limit(1)
              .maybeSingle();

      bool microchipPending = false;
      final Object? dogId = dogResponse?['id'];
      if (dogId != null) {
        try {
          final pendingRow = await Supabase.instance.client
              .from('microchip_submissions')
              .select('id')
              .eq('dog_id', dogId)
              .eq('status', 'pending')
              .limit(1)
              .maybeSingle();
          microchipPending = pendingRow != null;
        } catch (_) {}
      }

      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('daily_streak')
          .eq('id', userId)
          .single();

      final walksResponse = await Supabase.instance.client
          .from('walks')
          .select('distance_meters, walk_date, duration_seconds')
          .eq('user_id', userId);

;
      // "My coupons" subtitle: redeemed rewards not yet collected. Optional —
      // the rest of the profile still loads if this request fails.
      int? coupons;
      try {
        final redeemed = await SupabaseRewardsRepository().loadRedeemed();
        coupons = redeemed.where((r) => !r.isCollected).length;
      } catch (_) {}

      if (!mounted || request != _profileRequest) return;
      setState(() {
        _dogData = dogResponse;
        _dogRole = link?.role;
        _availableCoupons = coupons;
        _microchipPending = microchipPending;
        _dailyStreak = profileResponse['daily_streak'] ?? 0;
        
        _calculateCareScore(List<Map<String, dynamic>>.from(walksResponse), dogResponse);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || request != _profileRequest) return;
      setState(() => _isLoading = false);
    }
  }

  void _calculateCareScore(List<Map<String, dynamic>> walks, Map<String, dynamic>? dog) {
    if (dog == null) return;

    DateTime sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    List recentWalks = walks.where((w) => DateTime.parse(w['walk_date']).isAfter(sevenDaysAgo)).toList();
    
    final activeDays = recentWalks
        .map((w) => DateTime.parse(w['walk_date']).toLocal())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .length
        .clamp(0, 7);
    int activityScore = ((activeDays * 100) / 7).round().clamp(0, 100);
    int vaccScore = dog['vaccination_status'] == 'up_to_date' ? 100 : 0;
    int microchipScore = microchipNumberError(dog['microchip_number']?.toString() ?? '') == null ? 100 : 0;
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
    final String microchipStatus = microchipScore == 100
        ? 'Accepted · $microchipNum'
        : _microchipPending
        ? 'Certificate under review'
        : 'Verify to unlock rewards';
    
    final String vaccDate = dog['vaccination_date']?.toString() ?? '';
    final String vaccStatus = vaccDate.isNotEmpty ? 'Up to date' : 'Unknown';
    
    final String insuranceName = dog['insurance_partner']?.toString() ?? '';
    final String insuranceStatus = insuranceName.isNotEmpty ? insuranceName : 'Not added';

    final String vetDate = dog['last_vet_checkup']?.toString() ?? '';
    final String vetStatus = vetDate.isNotEmpty ? 'Up to date' : 'Book your next visit';

    Map<String, Map<String, dynamic>> components = {
      'Activity (7 days)': {'score': activityScore, 'status': '$activeDays/7 days active'},
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

  void _openCareScore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CareScoreScreen(
          careScore: _careScore,
          scoreComponents: _scoreComponents,
          dogData: _dogData,
        ),
      ),
    );
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

  bool get _microchipAccepted =>
      microchipNumberError(_dogData?['microchip_number']?.toString() ?? '') ==
      null;

  Future<void> _openActivityHistory() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const WalkHistoryScreen()),
  );

  Future<void> _openMyCoupons() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardsScreen(couponsOnly: true)),
    );
    _fetchProfile(); // coupon count may change after collecting
  }

  Future<void> _openMicrochip() async {
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
    if (updated == true) _fetchProfile();
  }

  void _openInviteCarer() {
    final dogId = _dogData?['id']?.toString();
    if (dogId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => ShareCodeScreen(
          dogId: dogId,
          dogName: _dogData?['dog_name']?.toString() ?? 'your dog',
          onDone: () => Navigator.pop(routeContext),
        ),
      ),
    );
  }

  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: const Center(child: VitailLoading()),
      );
    }

    final String dogName = _dogData?['dog_name'] ?? 'Your Dog';
    final String? photoUrl = _dogData?['photo_url'];
    final String microchipNum = _dogData?['microchip_number']?.toString() ?? '';
    final bool canInvite = _dogData?['id'] != null && _dogRole != 'carer';

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: settings + avatar (Figma 1038:186)
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Semantics(
                      button: true,
                      label: 'Settings',
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                          _fetchProfile();
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _kCoral,
                            shape: BoxShape.circle,
                          ),
                          child: const VitailIcon(
                            'settings',
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: GestureDetector(
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(dog: _dogData),
                          ),
                        );
                        if (changed == true) _fetchProfile();
                      },
                      child: SizedBox(
                        width: 136,
                        height: 132,
                        child: Stack(
                          children: [
                            DogAvatar(photoUrl: photoUrl, size: 128),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: _kCoral,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const VitailIcon(
                                  'pencil',
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                dogName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _dogSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 16),

              // Streak pill
              Center(
                child: Container(
                  width: 203,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _tealBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      VitailIcon('flame', color: _ink, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '$_dailyStreak days streak!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),
              Text(
                'CARE SCORE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),

              // Care score card (tap opens CareScoreScreen)
              InkWell(
                onTap: _openCareScore,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 143,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _cardShadow,
                  ),
                  child: SizedBox.square(
                    dimension: 90,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _careScore > 0 ? (_careScore / 100) : 1.0,
                          strokeWidth: 10,
                          color: _kGreen,
                          backgroundColor: _tealBg,
                        ),
                        Center(
                          child: Text(
                            _careScore > 0 ? '$_careScore' : '– –',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildRow(
                icon: 'footprints',
                title: 'Activity History',
                subtitle:
                    _scoreComponents['Activity (7 days)']?['status'] as String?,
                onTap: _openActivityHistory,
              ),
              _buildRow(
                icon: 'microchip',
                title: 'Microchip',
                subtitle: _microchipAccepted
                    ? 'Accepted · $microchipNum'
                    : _microchipPending
                    ? 'Certificate under review'
                    : 'Verify to unlock rewards',
                subtitleColor: _microchipAccepted ? _kGreen : null,
                onTap: _openMicrochip,
              ),
              _buildRow(
                icon: 'ticket',
                title: 'My coupons',
                subtitle: switch (_availableCoupons) {
                  null => null,
                  0 => 'None ready to collect',
                  final n => '$n available',
                },
                onTap: _openMyCoupons,
              ),
              if (canInvite)
                _buildRow(
                  icon: 'user-plus',
                  title: 'Invite a carer',
                  subtitle: 'Share your dog code',
                  onTap: _openInviteCarer,
                ),

              const SizedBox(height: 40),

              // Log out
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _card,
                    foregroundColor: _kCoral,
                    side: const BorderSide(color: _kCoral),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Log out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Bottom logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/brand/vitail-mark.png',
                    height: 58,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const VitailIcon('paw-print', color: _kCoral, size: 58),
                  ),
                  const SizedBox(width: 4),
                  Image.asset(
                    'assets/brand/vitail-title.png',
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Text(
                      'VITAIL',
                      style: TextStyle(
                        color: _kCoral,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required String icon,
    required String title,
    required String? subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _tileBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: VitailIcon(icon, size: 20, color: _ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: subtitleColor != null
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: subtitleColor ?? _muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  VitailIcon('chevron-right', color: _muted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
