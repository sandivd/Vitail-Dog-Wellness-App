import 'vitail_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingStyle {
  const OnboardingStyle._();

  static const Color background = Color(0xFFF4F0E9);
  static const Color ink = Color(0xFF211F1D);
  static const Color muted = Color(0xFF6E6A63);
  static const Color border = Color(0xFFDAD6CD);
  static const Color green = Color(0xFFAEC568);
  static const Color coral = Color(0xFFCD533B);

  static const String font = 'PlusJakartaSans';

  static TextStyle text(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) =>
      TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: coral,
        foregroundColor: Colors.white,
        disabledBackgroundColor: border,
        disabledForegroundColor: muted,
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        shape: const StadiumBorder(),
      );

  static Widget icon(String name, {double size = 24}) => SvgPicture.asset(
        'assets/icons/onboarding-$name.svg',
        width: size,
        height: size,
      );
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.busy = false,
  });

  final String title;

  final String? subtitle;

  final List<Widget> children;

  final VoidCallback? onBack;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: OnboardingStyle.text(24,
                              weight: FontWeight.w700, height: 1.3),
                        ),
                        if (Navigator.canPop(context)) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: busy
                                  ? null
                                  : (onBack ?? () => Navigator.maybePop(context)),
                              icon: OnboardingStyle.icon('back'),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: OnboardingStyle.text(24,
                              weight: FontWeight.w700, height: 1.3),
                        ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: OnboardingStyle.text(13,
                            color: OnboardingStyle.muted,
                            weight: FontWeight.w500,
                            height: 1.5),
                      ),
                    ],
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingBadge extends StatelessWidget {
  const OnboardingBadge({super.key, required this.icon, this.color});

  final String icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? OnboardingStyle.green;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: VitailIcon(icon, size: 28, color: tint),
    );
  }
}

class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? OnboardingStyle.coral : OnboardingStyle.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(
              14,
              color: OnboardingStyle.ink,
              weight: selected ? FontWeight.w600 : FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}