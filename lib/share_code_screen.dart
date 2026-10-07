import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'dog_sharing.dart';
import 'onboarding_style.dart';

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
  static const Color _linkBlue = Color(0xFF3F7FB5);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _share(String code) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Help walk ${widget.dogName} on Vitail! Use invite code $code or open https://${_link(code)}',
        subject: 'Join ${widget.dogName} on Vitail',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (mounted) setState(() => _shared = true);
  }

  void _retry() => setState(() => _code = shareCodeForDog(widget.dogId));

  Widget _codeCard(String code) => Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OnboardingStyle.border),
        ),
        child: Column(
          children: [
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: OnboardingStyle.text(32, weight: FontWeight.w700)
                  .copyWith(letterSpacing: 1.5),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _copy(code, 'Code'),
              child: Text(
                'Copy code',
                style: OnboardingStyle.text(13,
                    color: _linkBlue, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  Widget _linkRow(String code) => Container(
        padding: const EdgeInsets.only(left: 16, right: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OnboardingStyle.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _link(code),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OnboardingStyle.text(12,
                    color: OnboardingStyle.muted, weight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () => _copy('https://${_link(code)}', 'Link'),
              child: Text(
                'Copy',
                style: OnboardingStyle.text(12,
                    color: OnboardingStyle.muted, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  Widget _body() => FutureBuilder<String>(
        future: _code,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: OnboardingStyle.coral),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  "Couldn't create a share code right now.",
                  textAlign: TextAlign.center,
                  style: OnboardingStyle.text(14,
                      color: OnboardingStyle.muted, weight: FontWeight.w500),
                ),
                TextButton(
                  onPressed: _retry,
                  child: Text('Try again',
                      style: OnboardingStyle.text(14,
                          color: OnboardingStyle.coral)),
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
                style: OnboardingStyle.primaryButton,
                child: Text('Share link',
                    style: OnboardingStyle.text(16, color: Colors.white)),
              ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingStyle.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.maybePop(context),
                        icon: OnboardingStyle.icon('back'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 14),
                          Text('Share the code',
                              style: OnboardingStyle.text(24,
                                  weight: FontWeight.w700, height: 1.3)),
                          const SizedBox(height: 8),
                          Text(
                            'Share this code with co-owners, sitters, or household members so they can help walk ${widget.dogName}.',
                            style: OnboardingStyle.text(13,
                                color: OnboardingStyle.muted,
                                weight: FontWeight.w500,
                                height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          _body(),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: widget.onDone,
                              child: Text(
                                _shared ? 'Continue' : 'Skip for now',
                                style: OnboardingStyle.text(13,
                                    color: OnboardingStyle.muted,
                                    weight: FontWeight.w500),
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
    );
  }
}