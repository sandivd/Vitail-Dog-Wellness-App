import 'package:flutter/material.dart';
import 'vitail_icon.dart';
import 'vitail_snack.dart';

class CareScoreScreen extends StatelessWidget {
  const CareScoreScreen({
    super.key,
    required this.careScore,
    required this.scoreComponents,
    this.dogData,
  });

  final int careScore;
  final Map<String, Map<String, dynamic>> scoreComponents;
  final Map<String, dynamic>? dogData;

  // Design tokens matching the Figma design & Vitail styling
  static const Color _kPageBg = Color(0xFFF4F0E9);
  static const Color _kCard = Colors.white;
  static const Color _kInk = Color(0xFF211F1D);
  static const Color _kMuted = Color(0xFF6E6A63);
  static const Color _kGreen = Color(0xFFAEC568);
  static const Color _kTealRingBg = Color(0xFFDCEFEA);
  static const Color _kTagBg = Color(0xFFF7F5F0);
  static const Color _kCheerBg = Color(0xFFE8EFCF);
  static const Color _kCheerText = Color(0xFF5A7224);

  int get _positiveImpactCount {
    return scoreComponents.values
        .where((item) => ((item['score'] as num?) ?? 0) > 0)
        .length;
  }

  int get _needsFocusCount {
    return scoreComponents.values
        .where((item) => ((item['score'] as num?) ?? 0) == 0)
        .length;
  }

  String get _scoreStatusText {
    if (careScore <= 0) return 'No score yet';
    if (careScore >= 80) return 'Excellent score';
    if (careScore >= 50) return 'Good progress';
    return 'Building up';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildHeader(context),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Score Card
                    _buildMainScoreCard(),

                    const SizedBox(height: 14),

                    // Component Cards
                    ..._buildComponentCards(context),

                    const SizedBox(height: 20),

                    // Bottom Encouragement Banner
                    _buildEncouragementBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const VitailIcon('chevron-left', size: 24, color: _kInk),
            ),
          ),
          const Text(
            'Care Score',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Progress Indicator
          SizedBox(
            width: 124,
            height: 124,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: careScore > 0 ? (careScore / 100) : 1.0,
                  strokeWidth: 12,
                  color: _kGreen,
                  backgroundColor: careScore > 0 ? _kTealRingBg : _kGreen.withValues(alpha: 0.25),
                ),
                Center(
                  child: Text(
                    careScore > 0 ? '$careScore' : '--',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            _scoreStatusText,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Updates weekly based on the last 7 days',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kMuted,
            ),
          ),

          const SizedBox(height: 18),

          // Impact Chips
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _kTagBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$_positiveImpactCount positive impact',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _kTagBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$_needsFocusCount needs focus',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildComponentCards(BuildContext context) {
    // Specific icon mappings for each card
    final iconMap = {
      'Activity (7 days)': 'flame',
      'Vaccinations': 'badge-check',
      'Microchip': 'paw-print',
      'Insurance': 'heart',
      'Vet check-in': 'calendar',
    };

    return scoreComponents.entries.map((entry) {
      final title = entry.key;
      final subtitle = entry.value['status']?.toString() ?? '';
      final iconName = iconMap[title] ?? 'paw-print';

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () {
            showVitailSnack(
              context,
              '$title details coming soon',
              type: VitailSnackType.info,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon square
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kTagBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: VitailIcon(iconName, size: 20, color: _kMuted),
                  ),
                ),
                const SizedBox(width: 14),

                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _kMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const VitailIcon('chevron-right', size: 18, color: _kMuted),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEncouragementBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: _kCheerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Your pet is doing great! Keep it up 🐾',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _kCheerText,
        ),
      ),
    );
  }
}