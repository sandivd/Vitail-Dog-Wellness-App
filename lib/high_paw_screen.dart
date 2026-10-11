import 'vitail_icon.dart';
import 'vitail_back_button.dart';
import 'package:flutter/material.dart';

import 'onboarding_style.dart';
import 'microchip_screen.dart';
import 'onboarding_goal_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vitail_snack.dart';
import 'dart:async';

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


  static const int _floorMinutes = 1;
  static const int _ceilingMinutes = 180;
  static const int _stepMinutes = 1;

  static const int _rangeMinutes = 10;

  late int _minutes;
  bool _saving = false;

    Timer? _holdTimer;

  void _startHold(VoidCallback step) {
    _stopHold();
    step();
    int ticks = 0;
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      step();
      if (++ticks == 10) {
        t.cancel();
        _holdTimer = Timer.periodic(
            const Duration(milliseconds: 40), (_) => step());
      }
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  int get _recommended => widget.dailyGoalMins;
  int get _low =>
      (_recommended - _rangeMinutes).clamp(_floorMinutes, _ceilingMinutes);
  int get _high => _recommended + _rangeMinutes;

  @override
  void initState() {
    super.initState();
    _minutes = _recommended.clamp(_floorMinutes, _ceilingMinutes);
  }

  void _nudge(int delta) {
    final int next =
        (_minutes + delta).clamp(_floorMinutes, _ceilingMinutes);
    if (next != _minutes) setState(() => _minutes = next);
  }

  String? get _limitMessage {
    if (_minutes < _low) {
      return "Less than $_low min wouldn't count towards your goal.";
    }
    if (_minutes > _high) {
      return "More than $_high min isn't an appropriate amount for "
          "${widget.dogName}. For any questions, please reach out to "
          "our customer support.";
    }
    return null;
  }

  String get _guidance {
    final String who = (widget.breed == null || widget.breed!.isEmpty)
        ? 'Dogs like ${widget.dogName}'
        : '${widget.breed}s';
    return '$who typically need $_low–$_high min/day.';
  }

  int get _streakMinutes => (_minutes * 0.8).ceil();

  Future<void> _continue() async {
    if (_saving) return;
    final String? dogId = widget.dogId;

    if (dogId != null && _minutes != widget.dailyGoalMins) {
      setState(() => _saving = true);
      // Scale km with minutes, rounded down to 0.5 like ExerciseCalculator.
      double km = widget.dailyGoalKm * _minutes / widget.dailyGoalMins;
      km = (km * 2).floor() / 2;
      if (km <= 0) km = 0.5;

      try {
        await Supabase.instance.client.from('dogs').update({
          'daily_goal_minutes': _minutes,
          'daily_goal_km': km,
        }).eq('id', dogId);
      } catch (_) {
        if (mounted) {
          setState(() => _saving = false);
          showVitailSnack(context, "Couldn't save your walk goal. Please try again.",
              type: VitailSnackType.error);
        }
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      onboardingFadeRoute(MicrochipScreen(dogId: dogId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int barMax =
        (_recommended * 1.5).round().clamp(1, _ceilingMinutes);
    final double progress = (_minutes / barMax).clamp(0.0, 1.0);
    final double target = (_recommended / barMax).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: VitailBackButton(onPressed: () => Navigator.maybePop(context), color: OnboardingStyle.ink),
              ),
            ),

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
                          _goalCard(progress, target),
                          if (_limitMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _limitMessage!,
                              style: OnboardingStyle.text(12,
                                  color: OnboardingStyle.coral,
                                  weight: FontWeight.w500,
                                  height: 1.4),
                            ),
                          ],
                          const SizedBox(height: 22),
                          _sectionLabel(
                            'Daily streak',
                            'Your streak grows by one every day you complete your walk.',
                          ),
                          const SizedBox(height: 12),
                          _note(),
                          const SizedBox(height: 16),
                          _disclaimerCard(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
                        onPressed: _saving ? null : _continue,
                        style: OnboardingStyle.primaryButton,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text('Continue',
                                style: OnboardingStyle.text(16,
                                    color: Colors.white)),
                      ),
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

  Widget _goalCard(double progress, double target) => Container(
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
                  onTap: _minutes > _floorMinutes ? () => _nudge(-_stepMinutes) : null,                
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
                  onTap: _minutes < _ceilingMinutes ? () => _nudge(_stepMinutes) : null,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) => Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _chipTrack,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          OnboardingStyle.coral),
                    ),
                  ),
                  // Recommended-goal marker
                  Positioned(
                    left: c.maxWidth * target - 1,
                    top: -4,
                    child: Container(
                      width: 2,
                      height: 14,
                      decoration: BoxDecoration(
                        color: OnboardingStyle.ink,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recommended: $_recommended min',
              style: OnboardingStyle.text(12,
                  color: OnboardingStyle.muted, weight: FontWeight.w500),
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
      button: true,child: GestureDetector(
        onLongPressStart: onTap == null ? null : (_) => _startHold(onTap),
        onLongPressEnd: (_) => _stopHold(),
        onLongPressCancel: _stopHold,
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
          'Reach 80% of your goal ($_streakMinutes of $_minutes min) and you finish your streak for the day.',
          style: OnboardingStyle.text(13,
              color: OnboardingStyle.muted,
              weight: FontWeight.w500,
              height: 1.5),
        ),
      );

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