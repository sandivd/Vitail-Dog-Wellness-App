import 'vitail_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';
import 'onboarding_goal_screen.dart';
import 'onboarding_style.dart';
import 'vitail_snack.dart';

String? microchipNumberError(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return 'Enter your dog\'s 15-digit microchip number.';
  if (!RegExp(r'^\d{15}$').hasMatch(value)) {
    return 'A microchip number is exactly 15 digits.';
  }
  if (value.startsWith('999')) {
    return 'Numbers starting with 999 are test codes, not registered chips.';
  }
  return null;
}

enum _View { form, verified, failed, submitted }

class MicrochipScreen extends StatefulWidget {
  const MicrochipScreen({super.key});

  @override
  State<MicrochipScreen> createState() => _MicrochipScreenState();
}

class _MicrochipScreenState extends State<MicrochipScreen> {
  final TextEditingController _numberController = TextEditingController();

  _View _view = _View.form;
  bool _uploadTab = false;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.pushReplacement<void, void>(
      context,
      onboardingFadeRoute<void>(const HomeScreen()),
    );
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    final String? error = microchipNumberError(_numberController.text);
    setState(() => _view = error == null ? _View.verified : _View.failed);
  }

  void _back() {
    switch (_view) {
      case _View.form:
        Navigator.maybePop(context);
      case _View.failed:
      case _View.verified:
      case _View.submitted:
        setState(() => _view = _View.form);
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
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: _back,
                  icon: OnboardingStyle.icon('back'),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Container(
                      alignment: Alignment.topCenter,
                      padding: EdgeInsets.only(
                          top: constraints.maxHeight * 0.10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            layoutBuilder:
                                (currentChild, previousChildren) => Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                            child: KeyedSubtree(
                              key: ValueKey<String>('$_view-$_uploadTab'),
                              child: _body(),
                            ),
                          ),
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
    );
  }

  Widget _body() {
    switch (_view) {
      case _View.form:
        return _uploadTab ? _uploadForm() : _numberForm();
      case _View.verified:
        return _result(
          title: 'Microchip verified',
          message:
              'Nice, you\'re all set to redeem reward coupons too.',
          onContinue: _finish,
        );
      case _View.failed:
        return _failed();
      case _View.submitted:
        return _result(
          title: 'Certificate submitted',
          message:
              'We\'ve received your certificate. We\'ll verify it and get back to you within 24 hours.',
          onContinue: _finish,
        );
    }
  }

  Widget _title(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: OnboardingStyle.text(22, weight: FontWeight.w700, height: 1.3),
      );

  Widget _helper(String text) => Text(
        text,
        style: OnboardingStyle.text(12,
            color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
      );

  Widget _tabs() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE5DC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _tab('Enter number', !_uploadTab, () {
              setState(() => _uploadTab = false);
            }),
            _tab('Upload certificate', _uploadTab, () {
              setState(() => _uploadTab = true);
            }),
          ],
        ),
      );

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label,
              style: OnboardingStyle.text(
                13,
                color: active ? OnboardingStyle.ink : OnboardingStyle.muted,
                weight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );

  Widget _skipLink() => Center(
        child: TextButton(
          onPressed: _finish,
          child: Text(
            'Skip for now, use the app as a tracker & journal',
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(12,
                color: OnboardingStyle.muted, weight: FontWeight.w500),
          ),
        ),
      );

  Widget _numberForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _title("Add your dog's microchip"),
          ),
          const SizedBox(height: 20),
          _tabs(),
          const SizedBox(height: 14),
          _helper(
            'Optional: Needed only to redeem reward coupons. You can still track walks and keep a journal without it.',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Microchip number',
                  style: OnboardingStyle.text(13, weight: FontWeight.w600)),
              const Spacer(),
              Text('optional',
                  style: OnboardingStyle.text(12,
                      color: OnboardingStyle.muted, weight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            style: OnboardingStyle.text(14, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '15-digit number',
              hintStyle: OnboardingStyle.text(14,
                  color: OnboardingStyle.muted, weight: FontWeight.w400),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: _fieldBorder(OnboardingStyle.border),
              focusedBorder: _fieldBorder(OnboardingStyle.coral),
              border: _fieldBorder(OnboardingStyle.border),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _verify,
            style: OnboardingStyle.primaryButton,
            child: Text('Verify',
                style: OnboardingStyle.text(16, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          _skipLink(),
        ],
      );

  Widget _uploadForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _title("Add your dog's microchip"),
          ),
          const SizedBox(height: 20),
          _tabs(),
          const SizedBox(height: 14),
          _helper(
            'Optional: Needed only to redeem reward coupons. You can still track walks and keep a journal without it.',
          ),
          const SizedBox(height: 20),
          _uploadBox(dashed: false),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _view = _View.submitted),
            style: OnboardingStyle.primaryButton,
            child: Text('Submit certificate',
                style: OnboardingStyle.text(16, color: Colors.white)),
          ),
          const SizedBox(height: 8),
          _skipLink(),
        ],
      );

  Widget _failed() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _title("We couldn't verify that number"),
          ),
          const SizedBox(height: 12),
          _helper(
            'Double-check the number on your dog\'s chip, or upload a certificate and we\'ll confirm it for you.',
          ),
          const SizedBox(height: 24),
          _uploadBox(dashed: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _view = _View.submitted),
            style: OnboardingStyle.primaryButton,
            child: Text('Submit certificate',
                style: OnboardingStyle.text(16, color: Colors.white)),
          ),
          const SizedBox(height: 14),
          Text(
            'We\'ll review your certificate and get back to you within 1\u20132 business days.',
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(12,
                color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 8),
          _skipLink(),
        ],
      );

  Widget _result({
    required String title,
    required String message,
    required VoidCallback onContinue,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _title(title),
          const SizedBox(height: 28),
          const Center(child: OnboardingBadge(icon: 'badge-check')),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: OnboardingStyle.text(13,
                color: OnboardingStyle.muted, weight: FontWeight.w500, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: onContinue,
            style: OnboardingStyle.primaryButton,
            child: Text('Continue',
                style: OnboardingStyle.text(16, color: Colors.white)),
          ),
        ],
      );

  Widget _uploadBox({required bool dashed}) {
    final Widget inner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: dashed
            ? null
            : Border.all(color: OnboardingStyle.border),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF2EFE9),
              shape: BoxShape.circle,
            ),
            child: const VitailIcon('arrow-up',
                size: 18, color: OnboardingStyle.muted),
          ),
          const SizedBox(height: 12),
          Text('Upload microchip certificate',
              style: OnboardingStyle.text(14, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('PDF, JPG or PNG',
              style: OnboardingStyle.text(12,
                  color: OnboardingStyle.muted, weight: FontWeight.w500)),
        ],
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        showVitailSnack(
          context,
          'File picking is not wired up yet.',
          type: VitailSnackType.info,
        );
      },
      child: dashed
          ? CustomPaint(painter: _DashedBorderPainter(), child: inner)
          : inner,
    );
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = OnboardingStyle.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ));

    const double dash = 6;
    const double gap = 5;

    for (final metric in path.computeMetrics()) {      
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dash;
        canvas.drawPath(
          metric.extractPath(
              distance, next.clamp(0, metric.length).toDouble()),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}