import 'vitail_colors.dart';
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
    final colors = VitailColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
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
                    _buildMainScoreCard(context),

                    const SizedBox(height: 14),

                    // Component Cards
                    ..._buildComponentCards(context),

                    const SizedBox(height: 20),

                    // Bottom Encouragement Banner
                    _buildEncouragementBanner(context),
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
    final colors = VitailColors.of(context);
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
              icon: VitailIcon('chevron-left', size: 24, color: colors.ink),
            ),
          ),
          Text(
            'Care Score',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard(BuildContext context) {
    final colors = VitailColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: colors.card,
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
                  color: colors.green,
                  backgroundColor: careScore > 0
                      ? colors.tint(const Color(0xFFDCEFEA), colors.teal)
                      : colors.green.withValues(alpha: 0.25),
                ),
                Center(
                  child: Text(
                    careScore > 0 ? '$careScore' : '--',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Text(
            _scoreStatusText,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Updates weekly based on the last 7 days',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.muted,
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
                    color: colors.tint(const Color(0xFFF7F5F0)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$_positiveImpactCount positive impact',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.tint(const Color(0xFFF7F5F0)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '$_needsFocusCount needs focus',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
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
    final colors = VitailColors.of(context);
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
              color: colors.card,
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
                    color: colors.tint(const Color(0xFFF7F5F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: VitailIcon(iconName, size: 20, color: colors.muted),
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
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                VitailIcon('chevron-right', size: 18, color: colors.muted),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEncouragementBanner(BuildContext context) {
    final colors = VitailColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.tint(const Color(0xFFE8EFCF), colors.greenPale),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Your pet is doing great! Keep it up 🐾',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.greenInk,
        ),
      ),
    );
  }
}
