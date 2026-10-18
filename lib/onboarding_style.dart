import 'vitail_colors.dart';
import 'vitail_icon.dart';
import 'vitail_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingStyle {
  const OnboardingStyle._(this.colors);

  factory OnboardingStyle.of(BuildContext context) =>
      OnboardingStyle._(VitailColors.of(context));

  final VitailColors colors;

  Color get background => colors.background;
  Color get ink => colors.ink;
  Color get muted => colors.muted;
  Color get border => colors.tint(const Color(0xFFDAD6CD), colors.border);
  Color get green => colors.green;
  Color get coral => colors.tint(const Color(0xFFCD533B), colors.coral);
  Color get card => colors.card;

  static const String font = 'PlusJakartaSans';

  TextStyle text(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    double? height,
  }) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink,
    height: height,
  );

  ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: coral,
    foregroundColor: Colors.white,
    disabledBackgroundColor: border,
    disabledForegroundColor: muted,
    minimumSize: const Size.fromHeight(56),
    elevation: 0,
    shape: const StadiumBorder(),
  );

  Widget icon(String name, {double size = 24}) => SvgPicture.asset(
    'assets/icons/onboarding-$name.svg',
    width: size,
    height: size,
    colorFilter: colors.isDark
        ? ColorFilter.mode(muted, BlendMode.srcIn)
        : null,
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
    final style = OnboardingStyle.of(context);
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: style.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canPop)
              VitailBackButton(
                onPressed: busy
                    ? null
                    : (onBack ?? () => Navigator.maybePop(context)),
                color: style.ink,
              ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(28, canPop ? 0 : 26, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: style.text(
                              24,
                              weight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: style.text(
                                13,
                                color: style.muted,
                                weight: FontWeight.w500,
                                height: 1.5,
                              ),
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
          ],
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
    final style = OnboardingStyle.of(context);
    final Color tint = color ?? style.green;
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
    final style = OnboardingStyle.of(context);
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
            color: style.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? style.coral : style.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: style.text(
              14,
              color: style.ink,
              weight: selected ? FontWeight.w600 : FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
