import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared visual tokens for the onboarding flow.
///
/// These values are copied verbatim from `onboarding_view.dart` so the new
/// steps sit flush against the screens Jiani and Sandiv already built.
/// They are duplicated there as private constants — if we ever consolidate,
/// this file is the place they should all point at.
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

  /// Matches the coral stadium button on the existing onboarding screen.
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: coral,
        foregroundColor: Colors.white,
        disabledBackgroundColor: border,
        disabledForegroundColor: muted,
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        shape: const StadiumBorder(),
      );

  /// One of the four onboarding SVGs in assets/icons:
  /// back, calendar, camera, chevron.
  static Widget icon(String name, {double size = 24}) => SvgPicture.asset(
        'assets/icons/onboarding-$name.svg',
        width: size,
        height: size,
      );
}

/// Page chrome for an onboarding step: cream background, centred title with a
/// back chevron, and a max-width column — the same structure and spacing as
/// `OnboardingView` so steps don't visibly shift as the user moves through.
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

  /// Optional supporting line under the title.
  final String? subtitle;

  final List<Widget> children;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// Disables the back button while an async action is running.
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
                        if (Navigator.canPop(context))
                          Positioned(
                            left: -24,
                            top: -6,
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: busy
                                  ? null
                                  : (onBack ??
                                      () => Navigator.maybePop(context)),
                              icon: OnboardingStyle.icon('back'),
                            ),
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

/// Circular tinted badge shown above a question.
///
/// The Figma uses custom illustrations here; we only have four onboarding
/// SVGs in assets/icons, so this falls back to a Material icon. Swap for an
/// SvgPicture once the designer exports the real assets.
class OnboardingBadge extends StatelessWidget {
  const OnboardingBadge({super.key, required this.icon, this.color});

  final IconData icon;
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
      child: Icon(icon, size: 28, color: tint),
    );
  }
}

/// Full-width tappable answer card used by the goal steps.
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
            // The design marks selection with a coral outline rather than a
            // fill, so the card set stays visually calm.
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
