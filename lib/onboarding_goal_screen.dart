import 'package:flutter/material.dart';

import 'onboarding_style.dart';

class OnboardingGoalScreen extends StatefulWidget {
  const OnboardingGoalScreen({
    super.key,
    required this.title,
    required this.options,
    required this.badgeIcon,
    required this.onSelected,
    this.initialValue,
    this.requireConfirm = false,
  });

  final String title;

  final List<String> options;

  final IconData badgeIcon;

  final ValueChanged<String> onSelected;

  final String? initialValue;

  final bool requireConfirm;

  @override
  State<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends State<OnboardingGoalScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  void _choose(String option) {
    setState(() => _selected = option);
    if (!widget.requireConfirm) {
      widget.onSelected(option);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Navigator.canPop(context)
                    ? IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                        icon: OnboardingStyle.icon('back'),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.25),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: OnboardingBadge(icon: widget.badgeIcon)),
                          const SizedBox(height: 28),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: OnboardingStyle.text(
                              26,
                              weight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 32),
                          for (int i = 0; i < widget.options.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            OnboardingOptionCard(
                              label: widget.options[i],
                              selected: _selected == widget.options[i],
                              onTap: () => _choose(widget.options[i]),
                            ),
                          ],
                          if (widget.requireConfirm) ...[
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _selected == null
                                  ? null
                                  : () => widget.onSelected(_selected!),
                              style: OnboardingStyle.primaryButton,
                              child: Text('Continue',
                                  style: OnboardingStyle.text(16)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Route<T> onboardingFadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

class OnboardingGoalAnswers {
  const OnboardingGoalAnswers({
    required this.helpGoal,
    required this.mattersMost,
  });

  final String helpGoal;
  final String mattersMost;

  @override
  String toString() =>
      'OnboardingGoalAnswers(helpGoal: $helpGoal, mattersMost: $mattersMost)';
}

Future<OnboardingGoalAnswers?> runOnboardingGoals(BuildContext context) async {
  final String? help = await Navigator.push<String>(
    context,
    onboardingFadeRoute<String>(
      Builder(
        builder: (stepContext) => OnboardingGoalScreen(
          title: OnboardingGoals.helpTitle,
          options: OnboardingGoals.helpOptions,
          badgeIcon: Icons.pets,
          onSelected: (value) => Navigator.pop(stepContext, value),
        ),
      ),
    ),
  );

  if (help == null || !context.mounted) return null;

  final String? matters = await Navigator.push<String>(
    context,
    onboardingFadeRoute<String>(
      Builder(
        builder: (stepContext) => OnboardingGoalScreen(
          title: OnboardingGoals.mattersTitle,
          options: OnboardingGoals.mattersOptions,
          badgeIcon: Icons.favorite_border,
          onSelected: (value) => Navigator.pop(stepContext, value),
        ),
      ),
    ),
  );

  if (matters == null) return null;

  return OnboardingGoalAnswers(helpGoal: help, mattersMost: matters);
}

class OnboardingGoals {
  const OnboardingGoals._();

  static const String helpTitle = 'What would you like Vitail to help with?';
  static const List<String> helpOptions = [
    'Explore parks & walk-friendly spots',
    'Earn rewards for every walk',
    'Build a consistent walking routine',
  ];

  static const String mattersTitle = 'What matters most to you?';
  static const List<String> mattersOptions = [
    'Discovering dog-friendly places nearby',
    'Redeeming perks & rewards',
    'Tracking my walks and progress',
  ];
}