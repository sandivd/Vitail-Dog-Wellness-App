import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'walk_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'walk_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _totalPoints = 0;
  int _dailyStreak = 0;
  bool _isLoading = true;
  
  String _dogName = 'Dog';
  String? _dogPhotoUrl;
  double _dailyGoalKm = 3.0;
  int _dailyGoalMins = 60;
  double _currentKm = 0.0;
  int _currentMins = 0;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('total_points, daily_streak') 
          .eq('id', userId)
          .single();
      
      final dogRes = await Supabase.instance.client
          .from('dogs')
          .select('dog_name, photo_url, daily_goal_km, daily_goal_minutes')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();

      final today = DateTime.now().toIso8601String().split('T')[0];
      final walksRes = await Supabase.instance.client
          .from('walks')
          .select('distance_meters, duration_seconds')
          .eq('user_id', userId)
          .gte('walk_date', today);

      double kmToday = 0;
      int minsToday = 0;
      for (var walk in walksRes) {
        kmToday += (walk['distance_meters'] as num).toDouble() / 1000;
        minsToday += (walk['duration_seconds'] as num).toInt() ~/ 60;
      }

      setState(() {
        _totalPoints = profileRes['total_points'] ?? 0;
        _dailyStreak = profileRes['daily_streak'] ?? 0;
        _dogName = dogRes?['dog_name'] ?? 'Dog';
        _dogPhotoUrl = dogRes?['photo_url'];
        _dailyGoalKm = (dogRes?['daily_goal_km'] ?? 3.0).toDouble();
        _dailyGoalMins = (dogRes?['daily_goal_minutes'] ?? 60).toInt();
        _currentKm = kmToday;
        _currentMins = minsToday;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Custom Line Icons from Figma
  static const String homeIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M15 21V13C15 12.7348 14.8946 12.4804 14.7071 12.2929C14.5196 12.1054 14.2652 12 14 12H10C9.73478 12 9.48043 12.1054 9.29289 12.2929C9.10536 12.4804 9 12.7348 9 13V21" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M3 9.99999C2.99993 9.70906 3.06333 9.42161 3.18579 9.15771C3.30824 8.8938 3.4868 8.65979 3.709 8.47199L10.709 2.47199C11.07 2.1669 11.5274 1.99951 12 1.99951C12.4726 1.99951 12.93 2.1669 13.291 2.47199L20.291 8.47199C20.5132 8.65979 20.6918 8.8938 20.8142 9.15771C20.9367 9.42161 21.0001 9.70906 21 9.99999V19C21 19.5304 20.7893 20.0391 20.4142 20.4142C20.0391 20.7893 19.5304 21 19 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V9.99999Z" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const String exploreIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M15 20.7648C14.6897 20.7648 14.3836 20.6926 14.106 20.5538L9.894 18.4478C9.6164 18.3091 9.31033 18.2369 9 18.2369C8.68967 18.2369 8.3836 18.3091 8.106 18.4478L4.447 20.2778C4.29436 20.3541 4.12473 20.3901 3.95426 20.3823C3.78379 20.3745 3.61816 20.3232 3.47312 20.2332C3.32808 20.1433 3.20846 20.0178 3.12565 19.8686C3.04284 19.7194 2.99958 19.5515 3 19.3808V6.61784C3.0001 6.43218 3.05189 6.25021 3.14956 6.09231C3.24722 5.93442 3.38692 5.80683 3.553 5.72384L8.106 3.44684C8.3836 3.30812 8.68967 3.23591 9 3.23591C9.31033 3.23591 9.6164 3.30812 9.894 3.44684L14.106 5.55284C14.3836 5.69156 14.6897 5.76377 15 5.76377M15 5.76377C15.3103 5.76377 15.6164 5.69156 15.894 5.55284L19.553 3.72284C19.7056 3.6466 19.8751 3.61065 20.0455 3.61841C20.2159 3.62617 20.3814 3.67738 20.5265 3.76717C20.6715 3.85696 20.7911 3.98235 20.874 4.13142C20.9569 4.28049 21.0003 4.44828 21 4.61884V17.3828C20.9999 17.5685 20.9481 17.7505 20.8505 17.9084C20.7528 18.0663 20.6131 18.1938 20.447 18.2768L15.894 20.5538C15.6164 20.6926 15.3103 20.7648 15 20.7648M15 5.76377V20.7648M9 3.23591V18.2358" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const String rewardsIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 6.99995V20.9999M12 6.99995C11.6383 5.50935 11.0154 4.23501 10.2127 3.34311C9.41003 2.45121 8.46469 1.98314 7.5 1.99995C6.83696 1.99995 6.20107 2.26334 5.73223 2.73218C5.26339 3.20102 5 3.83691 5 4.49995C5 5.16299 5.26339 5.79887 5.73223 6.26772C6.20107 6.73656 6.83696 6.99995 7.5 6.99995M12 6.99995C12.3617 5.50935 12.9846 4.23501 13.7873 3.34311C14.59 2.45121 15.5353 1.98314 16.5 1.99995C17.163 1.99995 17.7989 2.26334 18.2678 2.73218C18.7366 3.20102 19 3.83691 19 4.49995C19 5.16299 18.7366 5.79887 18.2678 6.26772C17.7989 6.73656 17.163 6.99995 16.5 6.99995M20 10.9999V18.9999C20 19.5304 19.7893 20.0391 19.4142 20.4142C19.0391 20.7893 18.5304 21 18 20.9999H6C5.46957 20.9999 4.96086 20.7893 4.58579 20.4142C4.21071 20.0391 4 19.5304 4 18.9999V10.9999" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M20 7H4C3.44772 7 3 7.44772 3 8V10C3 10.5523 3.44772 11 4 11H20C20.5523 11 21 10.5523 21 10V8C21 7.44772 20.5523 7 20 7Z" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  static const String profileIconSvg = '''
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 13C14.7614 13 17 10.7614 17 8C17 5.23858 14.7614 3 12 3C9.23858 3 7 5.23858 7 8C7 10.7614 9.23858 13 12 13Z" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M20 21C20 18.8783 19.1571 16.8434 17.6569 15.3431C16.1566 13.8429 14.1217 13 12 13C9.87827 13 7.84344 13.8429 6.34315 15.3431C4.84285 16.8434 4 18.8783 4 21" stroke="[[COLOR]]" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    final screens = [
      // Index 0: Home
      Container(
        color: colorScheme.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.onSurfaceVariant.withOpacity(0.2),
                    backgroundImage: _dogPhotoUrl != null 
                        ? CachedNetworkImageProvider(_dogPhotoUrl!) 
                        : null,
                    child: _dogPhotoUrl == null ? Icon(Icons.pets, color: colorScheme.onSurfaceVariant) : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Hi $_dogName!',
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: colorScheme.onSurface,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 186,
                        height: 186,
                        child: CircularProgressIndicator(
                          value: (_currentKm / _dailyGoalKm).clamp(0.0, 1.0),
                          strokeWidth: 14,
                          color: colorScheme.secondary,
                          backgroundColor: colorScheme.secondary.withOpacity(0.2),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: (_currentMins / _dailyGoalMins).clamp(0.0, 1.0),
                          strokeWidth: 10,
                          color: colorScheme.tertiary,
                          backgroundColor: colorScheme.tertiary.withOpacity(0.2),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_currentKm.toStringAsFixed(1)}/${_dailyGoalKm.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, 
                              color: colorScheme.secondary, 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          Text(
                            'KM',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, 
                              color: colorScheme.onSurfaceVariant, 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          const SizedBox(height: 4), 
                          
                          Text(
                            '$_currentMins/$_dailyGoalMins',
                            style: TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800, 
                              color: colorScheme.tertiary, 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                          Text(
                            'MINS',
                            style: TextStyle(
                              fontSize: 14, 
                              fontWeight: FontWeight.w800, 
                              color: colorScheme.onSurfaceVariant, 
                              fontFamily: 'PlusJakartaSans',
                              height: 1.0, 
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: _buildFigmaStatCard('Points earned', '$_totalPoints pts', Icons.star, context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFigmaStatCard('Streaks', '$_dailyStreak days', Icons.local_fire_department, context),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text('Start walk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WalkHistoryScreen()));
                  },
                  child: Text(
                    'View Walk History', 
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const WalkScreen(),
      const RewardsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.onSurfaceVariant.withOpacity(0.2), width: 1)),
        ),
        padding: EdgeInsets.only(
          top: 8.0,
          bottom: MediaQuery.of(context).padding.bottom > 0 ? 16.0 : 8.0, 
        ),
        child: Row(
          children: [
            _buildCustomNavItem(0, 'Home', homeIconSvg, context),
            _buildCustomNavItem(1, 'Explore', exploreIconSvg, context),
            _buildCustomNavItem(2, 'Rewards', rewardsIconSvg, context),
            _buildCustomNavItem(3, 'Profile', profileIconSvg, context),
          ],
        ),
      ),
    );
  }

  Widget _buildFigmaStatCard(String title, String value, IconData icon, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurfaceVariant.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            value, 
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: colorScheme.onSurface,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            style: TextStyle(
              fontSize: 12, 
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomNavItem(int index, String label, String svgString, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isActive = _currentIndex == index;
    
    // Active is primary, inactive is muted grey
    String hexColor = isActive ? '#${colorScheme.primary.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}' : '#${colorScheme.onSurfaceVariant.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}'; 
    
    String coloredSvg = svgString.replaceAll('[[COLOR]]', hexColor);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
            if (index == 0) _fetchHomeData();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(coloredSvg, height: 24, width: 24),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant, 
                fontSize: 12,
                fontFamily: 'PlusJakartaSans',
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              )
            ),
          ],
        ),
      ),
    );
  }
}