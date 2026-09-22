import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'check_in_screen.dart';
import 'reward_details_screen.dart';
import 'reward_image_placeholder.dart';
import 'rewards_data.dart';

class RewardFlow extends StatefulWidget {
  const RewardFlow({
    super.key,
    required this.offer,
    required this.repository,
    required this.canRedeem,
    required this.onChanged,
    this.redemption,
    this.openRedemption = false,
  });
  final RewardOffer offer;
  final RewardsRepository repository;
  final bool canRedeem;
  final RedeemedReward? redemption;
  final bool openRedemption;
  final ValueChanged<RedeemedReward> onChanged;

  @override
  State<RewardFlow> createState() => _RewardFlowState();
}

class _RewardFlowState extends State<RewardFlow> {
  late RedeemedReward? _reward = widget.redemption;
  final _progress = ValueNotifier<String?>(null);
  final _requestId = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  bool _busy = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.openRedemption && _reward == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRedemption();
      });
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy || _reward != null) return;
    _busy = true;
    _progress.value = 'busy';
    try {
      final reward = await widget.repository.redeem(widget.offer, _requestId);
      // Update the catalogue even if this route or its sheet was dismissed.
      widget.onChanged(reward);
      if (!mounted) return;
      setState(() => _reward = reward);
      _progress.value = 'success';
    } catch (_) {
      if (mounted) {
        _progress.value =
            'We couldn’t confirm redemption. Please retry. You won’t be charged twice for this request.';
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _showRedemption() async {
    if (_sheetOpen || _reward != null) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ValueListenableBuilder<String?>(
        valueListenable: _progress,
        builder: (_, status, _) {
          final success = status == 'success';
          final busy = status == 'busy';
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Text('×', style: TextStyle(fontSize: 26)),
                      ),
                    ),
                    if (success)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF2F6E7),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SvgPicture.asset(
                          'assets/icons/reward-collected-check.svg',
                        ),
                      )
                    else
                      const SizedBox.square(
                        dimension: 72,
                        child: ClipOval(child: RewardImagePlaceholder()),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      success ? 'Redeemed!' : widget.offer.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      success
                          ? 'Your reward is ready. Check in when you’re at the counter.'
                          : '${NumberFormat.decimalPattern('en').format(widget.offer.pointsCost)} points',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (status != null && !success && !busy) ...[
                      const SizedBox(height: 12),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : success
                            ? () => Navigator.pop(sheetContext)
                            : _redeem,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                success ? 'View reward' : 'Redeem Offer',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    _sheetOpen = false;
  }

  Future<void> _checkIn() async {
    final reward = _reward;
    if (reward == null) return;
    await Navigator.push<RedeemedReward>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckInScreen(
          reward: reward,
          onCollect: () async {
            final collected = await widget.repository.collect(reward);
            widget.onChanged(collected);
            if (mounted) setState(() => _reward = collected);
            return collected;
          },
        ),
      ),
    );
  }

  void _showCode() {
    final reward = _reward!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your promo code'),
        content: SelectableText(
          reward.promoCode,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reward.promoCode));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard!')),
              );
            },
            child: const Text('Copy code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RewardDetailsScreen(
    offer: widget.offer,
    canRedeem: widget.canRedeem,
    onRedeem: _showRedemption,
    redemption: _reward,
    onCheckIn: _checkIn,
    onShowCode: _showCode,
  );
}
