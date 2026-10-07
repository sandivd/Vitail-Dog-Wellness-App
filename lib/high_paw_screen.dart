import 'vitail_icon.dart';
import 'package:flutter/material.dart';

import 'onboarding_style.dart';
import 'microchip_screen.dart';
import 'onboarding_goal_screen.dart';


class HighPawScreen extends StatefulWidget {
  final String dogName;
  final int dailyGoalMins;
  final double dailyGoalKm;
  final String? breed;
  final String? dogId;

  const HighPawScreen({
    super.key,
    required this.dogName,
    required this.dailyGoalMins,
    required this.dailyGoalKm,
    this.breed,
    this.dogId,
  });

  @override
  State<HighPawScreen> createState() => _HighPawScreenState();
}

class _HighPawScreenState extends State<HighPawScreen> {
  static const int _minMinutes = 10;
  static const int _maxMinutes = 120;
  static const int _stepMinutes = 5;

  static const Color _teal = Color(0xFFD5E7E4);
  static const Color _tealInk = Color(0xFF5F98BD);
  static const Color _chipTrack = Color(0xFFF2EFE9);
  static const Color _noteCard = Color(0xFFFBF9F5);
  static const Color _noteBorder = Color(0xFFE5E0D7);

  // Disclaimer box: same "note" anatomy as _noteCard, but a very light
  // red tint so it reads as an advisory.
  static const Color _disclaimerCardBg = Color(0xFFFBEFED);
  static const Color _disclaimerBorder = Color(0xFFF0D9D5);

  static const String _disclaimer =
      'This guidance is for general wellbeing only and does not '
      'replace professional veterinary advice. Every dog is unique, '
      'so always consider your dog’s age, breed, health, and '
      'individual needs alongside advice from your vet.';

  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late int _minutes;
  final Set<int> _days = <int>{};

  @override
  void initState() {
    super.initState();
    _minutes = widget.dailyGoalMins.clamp(_minMinutes, _maxMinutes);
  }

  void _nudge(int delta) {
    final int next = (_minutes + delta).clamp(_minMinutes, _maxMinutes);
    if (next != _minutes) setState(() => _minutes = next);
  }

  String get _guidance {
    final int low = ((_roundTo5(widget.dailyGoalMins * 0.8)))
        .clamp(_minMinutes, _maxMinutes);
    final int high = ((_roundTo5(widget.dailyGoalMins * 1.2)))
        .clamp(_minMinutes, _maxMinutes);
    final String who = (widget.breed == null || widget.breed!.isEmpty)
        ? 'Dogs like ${widget.dogName}'
        : '${widget.breed}s';
    return '$who typically need $low–$high min/day.';
  }

  static int _roundTo5(double value) => (value / 5).round() * 5;

  @override
  Widget build(BuildContext context) {
    final double progress =
        (_minutes - _minMinutes) / (_maxMinutes - _minMinutes);

    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: OnboardingStyle.icon('back'),
                ),
              ),
            ),
            // The plan content scrolls only if it genuinely can't fit
            // (small screens, large text scale)...
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Here's your plan",
                            textAlign: TextAlign.center,
                            style: OnboardingStyle.text(22,
                                weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),
                          _banner(),
                          const SizedBox(height: 22),
                          _sectionLabel('Walk goal', _guidance),
                          const SizedBox(height: 12),
                          _goalCard(progress),
                          const SizedBox(height: 22),
                          _sectionLabel(
                            'This week',
                            '${_days.length} of 7 days picked — miss one and catch up before Sunday.',
                          ),
                          const SizedBox(height: 12),
                          _weekCard(),
                          const SizedBox(height: 16),
                          _note(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ...but the Continue button and the disclaimer are PINNED:
            // never pushed off-screen, always fully visible.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          onboardingFadeRoute(MicrochipScreen(dogId: widget.dogId)),                        ),
                        style: OnboardingStyle.primaryButton,
                        child: Text('Continue',
                            style: OnboardingStyle.text(16,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 12),
                      _disclaimerCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR ROUTINE PLAN IS READY',
              style: OnboardingStyle.text(11, color: _tealInk).copyWith(
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A simpler routine for happier, active days',
              style: OnboardingStyle.text(15,
                  weight: FontWeight.w700, height: 1.4),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: OnboardingStyle.text(15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: OnboardingStyle.text(13,
                color: OnboardingStyle.muted,
                weight: FontWeight.w500,
                height: 1.4),
          ),
        ],
      );

  Widget _goalCard(double progress) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OnboardingStyle.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _stepButton(
                  icon: 'minus',
                  filled: false,
                  onTap: _minutes > _minMinutes ? () => _nudge(-_stepMinutes) : null,
                ),
                Expanded(
                  child: Text(
                    '$_minutes min',
                    textAlign: TextAlign.center,
                    style:
                        OnboardingStyle.text(20, weight: FontWeight.w700),
                  ),
                ),
                _stepButton(
                  icon: 'plus',
                  filled: true,
                  onTap: _minutes < _maxMinutes ? () => _nudge(_stepMinutes) : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: _chipTrack,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(OnboardingStyle.coral),
              ),
            ),
          ],
        ),
      );

  Widget _stepButton({
    required String icon,
    required bool filled,
    VoidCallback? onTap,
  }) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: filled
                ? (enabled
                    ? OnboardingStyle.coral
                    : OnboardingStyle.coral.withValues(alpha: 0.4))
                : _chipTrack,
            shape: BoxShape.circle,
          ),
          child: VitailIcon(
            icon,
            size: 22,
            color: filled
                ? Colors.white
                : (enabled ? OnboardingStyle.ink : OnboardingStyle.muted),
          ),
        ),
      ),
    );
  }

  Widget _weekCard() => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: OnboardingStyle.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < _dayLabels.length; i++)
              _dayChip(i, _dayLabels[i]),
          ],
        ),
      );

  Widget _dayChip(int index, String label) {
    final bool selected = _days.contains(index);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() {
          if (!_days.remove(index)) _days.add(index);
        }),
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? OnboardingStyle.green : _chipTrack,
            shape: BoxShape.circle,
          ),
          child: Text(
            label,
            style: OnboardingStyle.text(
              13,
              color: selected ? Colors.white : OnboardingStyle.muted,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _note() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _noteCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _noteBorder),
        ),
        child: Text(
          'Miss a day? No stress — your weekly goal still counts, so you can catch up any day before the week resets.',
          style: OnboardingStyle.text(13,
              color: OnboardingStyle.muted,
              weight: FontWeight.w500,
              height: 1.5),
        ),
      );

  /// Vet-advice disclaimer: same "note" box shape as [_note], with a very
  /// light red background. Lives in the pinned footer, so it is always
  /// fully visible — compact padding/line-height to keep the footer short.
  Widget _disclaimerCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _disclaimerCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _disclaimerBorder),
        ),
        child: Text(
          _disclaimer,
          textAlign: TextAlign.center,
          style: OnboardingStyle.text(11,
              color: OnboardingStyle.muted,
              weight: FontWeight.w500,
              height: 1.45),
        ),
      );
}