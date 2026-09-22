import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'reward_image_placeholder.dart';
import 'rewards_data.dart';

/// Collects an already-paid reward. This screen never deducts points.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({
    super.key,
    required this.reward,
    required this.onCollect,
  });
  final RedeemedReward reward;
  final Future<RedeemedReward> Function() onCollect;

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  double _swipe = 0;
  bool _busy = false;
  String? _error;
  late RedeemedReward? _collected = widget.reward.isCollected
      ? widget.reward
      : null;

  Future<void> _collect() async {
    if (_busy || _collected != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await widget.onCollect();
      if (!receipt.isCollected) {
        throw StateError('Collection not confirmed');
      }
      if (mounted) setState(() => _collected = receipt);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Collection couldn’t be confirmed. Please swipe again to retry.';
          _swipe = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color get _card => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF242321)
      : Colors.white;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      64,
                      24,
                      _collected == null ? 48 : 64,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _collected == null
                          ? _swipeContent()
                          : _receiptContent(_collected!),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context, _collected),
              icon: const Text('×', style: TextStyle(fontSize: 26)),
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _swipeContent() {
    final reward = widget.reward;
    final colors = Theme.of(context).colorScheme;
    return [
      const Text(
        'Please show to staff',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 18),
      Text(
        'Swipe to collect',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      const SizedBox(height: 18),
      Text(
        'Once you swipe, your offer will be collected and it can’t be undone.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const RewardImagePlaceholder(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reward.partnerName ?? 'Partner details unavailable',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      reward.pointsCost == null
                          ? 'Redeemed'
                          : '${NumberFormat.decimalPattern('en').format(reward.pointsCost)} pts',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 54),
      if (_error != null) ...[
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.error),
        ),
        const SizedBox(height: 12),
      ],
      _slider(),
    ];
  }

  Widget _slider() {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = math.max(1.0, constraints.maxWidth - 64);
        return Semantics(
          label: 'Swipe to collect reward',
          value: '${(_swipe * 100).round()} percent',
          increasedValue:
              '${((_swipe + 0.25).clamp(0, 1) * 100).round()} percent',
          onIncrease: _busy
              ? null
              : () {
                  setState(() => _swipe = (_swipe + 0.25).clamp(0, 1));
                  if (_swipe >= 1) _collect();
                },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF302E2B)
                  : const Color(0xFFF9F7F3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? colors.outline
                    : const Color(0xFFDBD7D1),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 68, right: 30),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        const Text(
                          'SWIPE TO COLLECT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 22),
                        SvgPicture.asset(
                          'assets/icons/reward-swipe-arrow.svg',
                          width: 18,
                          height: 18,
                          colorFilter: ColorFilter.mode(
                            colors.onSurface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 3 + _swipe * maxDrag,
                  top: 3,
                  child: GestureDetector(
                    key: const ValueKey('collect-swipe-knob'),
                    onHorizontalDragUpdate: _busy
                        ? null
                        : (details) => setState(
                            () => _swipe = (_swipe + details.delta.dx / maxDrag)
                                .clamp(0, 1),
                          ),
                    onHorizontalDragEnd: _busy
                        ? null
                        : (_) {
                            if (_swipe > 0.9) {
                              _collect();
                            } else {
                              setState(() => _swipe = 0);
                            }
                          },
                    onHorizontalDragCancel: () {
                      if (!_busy) setState(() => _swipe = 0);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _busy
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const WhiteRewardLogo(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _receiptContent(RedeemedReward reward) => [
    Center(
      child: Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFFF2F6E7),
          shape: BoxShape.circle,
        ),
        child: SvgPicture.asset(
          'assets/icons/reward-collected-check.svg',
          width: 40,
          height: 40,
        ),
      ),
    ),
    const SizedBox(height: 18),
    const Text(
      'Collected!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 60),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.outline
              : const Color(0xFFDBD7D1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          _receiptRow('Order', reward.title),
          const Divider(height: 1, color: Color(0xFFDBD7D1)),
          _receiptRow(
            'Place',
            reward.partnerName ?? 'Partner details unavailable',
          ),
        ],
      ),
    ),
    const SizedBox(height: 32),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FilledButton(
        onPressed: () => Navigator.pop(context, reward),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('DONE'),
      ),
    ),
  ];

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
