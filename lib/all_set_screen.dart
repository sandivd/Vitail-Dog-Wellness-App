import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'onboarding_goal_screen.dart';
import 'onboarding_style.dart';
import 'vitail_colors.dart';


class AllSetScreen extends StatefulWidget {
  const AllSetScreen({super.key, required this.dogId});

  final String dogId;

  @override
  State<AllSetScreen> createState() => _AllSetScreenState();
}

class _AllSetScreenState extends State<AllSetScreen> {
  VitailColors get _colors => VitailColors.of(context);
  OnboardingStyle get _style => OnboardingStyle.of(context);

  bool _loading = true;
  String _dogName = 'your dog';
  int? _minutes;
  double? _km;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from('dogs')
          .select('dog_name, daily_goal_minutes, daily_goal_km')
          .eq('id', widget.dogId)
          .maybeSingle();
      if (row != null) {
        final String? name = (row['dog_name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) _dogName = name;
        _minutes = (row['daily_goal_minutes'] as num?)?.toInt();
        _km = (row['daily_goal_km'] as num?)?.toDouble();
      }
    } catch (_) {
      // If the read fails we still let them continue home.
    }
    if (mounted) setState(() => _loading = false);
  }

  void _goHome() {
    Navigator.pushReplacement<void, void>(
      context,
      onboardingFadeRoute<void>(const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.22),
        _style.background,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                decoration: BoxDecoration(
                  color: _style.background,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _content(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ALL SET!',
            textAlign: TextAlign.center,
            style: _style.text(26, weight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            "Here's $_dogName's daily goal:",
            textAlign: TextAlign.center,
            style: _style.text(13,
                color: _style.muted, weight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 18),
          _goalCard(),
          const SizedBox(height: 16),
          Text(
            'Take breaks when $_dogName needs them, and go by how they '
            'feel on the day.',
            style: _style.text(12,
                color: _style.muted, weight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _goHome,
            style: _style.primaryButton,
            child: Text('Continue to Home',
                style: _style.text(16, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          Text(
            'You can change your goal anytime in Edit Profile',
            textAlign: TextAlign.center,
            style: _style.text(11,
                color: _style.muted, weight: FontWeight.w500),
          ),
        ],
      );

  Widget _goalCard() => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: _colors.teal,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAILY GOAL',
              style: _style
                  .text(11, color: _colors.blue)
                  .copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            if (_minutes != null) ...[
              Text('$_minutes minutes',
                  style: _style.text(24, weight: FontWeight.w700)),
              if (_km != null)
                Text('${_km!.toStringAsFixed(1)} KM',
                    style: _style.text(24, weight: FontWeight.w700)),
            ] else
              Text('Your plan is saved',
                  style: _style.text(18, weight: FontWeight.w700)),
          ],
        ),
      );
}