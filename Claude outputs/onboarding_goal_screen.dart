import 'package:flutter/material.dart';

import 'onboarding_style.dart';

Route<T> onboardingFadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      opaque: true,
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

void startOnboardingGoals(
  BuildContext context, {
  required Widget Function(OnboardingGoalAnswers answers) nextScreenBuilder,
}) {
  Navigator.push<void>(
    context,
    onboardingFadeRoute<void>(_GoalFlow(nextScreenBuilder: nextScreenBuilder)),
  );
}

class _GoalFlow extends StatefulWidget {
  const _GoalFlow({required this.nextScreenBuilder});

  final Widget Function(OnboardingGoalAnswers answers) nextScreenBuilder;

  @override
  State<_GoalFlow> createState() => _GoalFlowState();
}

class _GoalFlowState extends State<_GoalFlow> {
  int _step = 0;
  String? _help;
  String? _matters;

  void _back() {
    if (_step == 0) {
      Navigator.maybePop(context);
    } else {
      setState(() => _step = 0);
    }
  }

  void _select(String value) {
    if (_step == 0) {
      setState(() {
        _help = value;
        _step = 1;
      });
      return;
    }

    _matters = value;
    Navigator.pushReplacement<void, void>(
      context,
      onboardingFadeRoute<void>(
        widget.nextScreenBuilder(
          OnboardingGoalAnswers(
            helpGoal: _help ?? '',
            mattersMost: _matters ?? '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool onFirstStep = _step == 0;

    return PopScope(
      canPop: onFirstStep,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
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
                    onPressed: _back,
                    icon: OnboardingStyle.icon('back'),
                  ),
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          ),
                          child: _GoalQuestion(
                            key: ValueKey<int>(_step),
                            title: onFirstStep
                                ? OnboardingGoals.helpTitle
                                : OnboardingGoals.mattersTitle,
                            options: onFirstStep
                                ? OnboardingGoals.helpOptions
                                : OnboardingGoals.mattersOptions,
                            badgeIcon:
                                onFirstStep ? Icons.pets : Icons.favorite_border,
                            initialValue: onFirstStep ? _help : _matters,
                            onSelected: _select,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalQuestion extends StatefulWidget {
  const _GoalQuestion({
    super.key,
    required this.title,
    required this.options,
    required this.badgeIcon,
    required this.onSelected,
    this.initialValue,
  });

  final String title;
  final List<String> options;
  final IconData badgeIcon;
  final ValueChanged<String> onSelected;
  final String? initialValue;

  @override
  State<_GoalQuestion> createState() => _GoalQuestionState();
}

class _GoalQuestionState extends State<_GoalQuestion> {
  static const double _titleBlockHeight = 82;

  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  void _choose(String option) {
    setState(() => _selected = option);
    widget.onSelected(option);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: OnboardingBadge(icon: widget.badgeIcon)),
        const SizedBox(height: 28),
        SizedBox(
          height: _titleBlockHeight,
          child: Center(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: OnboardingStyle.text(
                26,
                weight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < widget.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          OnboardingOptionCard(
            label: widget.options[i],
            selected: _selected == widget.options[i],
            onTap: () => _choose(widget.options[i]),
          ),
        ],
      ],
    );
  }
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
