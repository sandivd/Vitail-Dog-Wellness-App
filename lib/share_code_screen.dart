import 'vitail_colors.dart';
import 'package:flutter/material.dart';
import 'vitail_back_button.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'dog_sharing.dart';
import 'onboarding_style.dart';
import 'vitail_snack.dart';

class ShareCodeScreen extends StatefulWidget {
  const ShareCodeScreen({
    super.key,
    required this.dogId,
    required this.dogName,
    required this.onDone,
  });

  final String dogId;
  final String dogName;
  final VoidCallback onDone;

  @override
  State<ShareCodeScreen> createState() => _ShareCodeScreenState();
}

class _ShareCodeScreenState extends State<ShareCodeScreen> {
  VitailColors get _colors => VitailColors.of(context);

  OnboardingStyle get _style => OnboardingStyle.of(context);

  Color get _linkBlue =>
      _colors.tint(const Color(0xFF3F7FB5), const Color(0xFF8EBBD7));

  late Future<String> _code;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    _code = shareCodeForDog(widget.dogId);
  }

  String _link(String code) =>
      'vitail.online/i/${code.replaceAll('-', '').toLowerCase()}';

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showVitailSnack(context, '$label copied', type: VitailSnackType.success);
  }

  Future<void> _share(String code) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Help walk ${widget.dogName} on Vitail! Use invite code $code or open https://${_link(code)}',
        subject: 'Join ${widget.dogName} on Vitail',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (mounted) setState(() => _shared = true);
  }

  void _retry() => setState(() => _code = shareCodeForDog(widget.dogId));

  Widget _codeCard(String code) => Container(
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
    decoration: BoxDecoration(
      color: _colors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _style.border),
    ),
    child: Column(
      children: [
        SelectableText(
          code,
          textAlign: TextAlign.center,
          style: _style
              .text(32, weight: FontWeight.w700)
              .copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => _copy(code, 'Code'),
          child: Text(
            'Copy code',
            style: _style.text(13, color: _linkBlue, weight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Widget _linkRow(String code) => Container(
    padding: const EdgeInsets.only(left: 16, right: 4),
    decoration: BoxDecoration(
      color: _colors.card.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _style.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _link(code),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style.text(
              12,
              color: _style.muted,
              weight: FontWeight.w500,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _copy('https://${_link(code)}', 'Link'),
          child: Text(
            'Copy',
            style: _style.text(
              12,
              color: _style.muted,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _body() => FutureBuilder<String>(
    future: _code,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator(color: _style.coral)),
        );
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Column(
          children: [
            const SizedBox(height: 24),
            Text(
              "Couldn't create a share code right now.",
              textAlign: TextAlign.center,
              style: _style.text(
                14,
                color: _style.muted,
                weight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: _retry,
              child: Text(
                'Try again',
                style: _style.text(14, color: _style.coral),
              ),
            ),
          ],
        );
      }
      final code = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _codeCard(code),
          const SizedBox(height: 14),
          _linkRow(code),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _share(code),
            style: _style.primaryButton,
            child: Text(
              'Share link',
              style: _style.text(16, color: Colors.white),
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _style.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VitailBackButton(
              onPressed: () => Navigator.maybePop(context),
              color: _style.ink,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 14),
                                Text(
                                  'Share the code',
                                  style: _style.text(
                                    24,
                                    weight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Share this code with co-owners, sitters, or household members so they can help walk ${widget.dogName}.',
                                  style: _style.text(
                                    13,
                                    color: _style.muted,
                                    weight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _body(),
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: widget.onDone,
                                    child: Text(
                                      _shared ? 'Continue' : 'Skip for now',
                                      style: _style.text(
                                        13,
                                        color: _style.muted,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
