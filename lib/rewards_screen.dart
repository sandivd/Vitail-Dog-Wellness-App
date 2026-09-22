import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'reward_flow.dart';
import 'rewards_data.dart';
import 'reward_image_placeholder.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, this.repository, this.isActive = true});

  final RewardsRepository? repository;
  final bool isActive;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late final RewardsRepository _repository;
  RewardsCatalogue? _catalogue;
  List<RedeemedReward>? _redeemed;
  bool _showMine = false;
  bool _loadingCatalogue = true;
  bool _loadingRedeemed = false;
  String? _catalogueError;
  String? _redeemedError;
  int _catalogueRequest = 0;
  int _redeemedRequest = 0;
  final _number = NumberFormat.decimalPattern('en');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseRewardsRepository();
    _loadCatalogue();
    _loadRedeemed();
  }

  @override
  void didUpdateWidget(covariant RewardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _refresh();
  }

  Future<void> _loadCatalogue() async {
    final request = ++_catalogueRequest;
    setState(() {
      _loadingCatalogue = true;
      _catalogueError = null;
    });
    try {
      final catalogue = await _repository.loadCatalogue();
      if (!mounted || request != _catalogueRequest) return;
      final sortedOffers = List<RewardOffer>.of(catalogue.offers)
        ..sort((a, b) {
          final costOrder = a.pointsCost.compareTo(b.pointsCost);
          return costOrder != 0 ? costOrder : a.id.compareTo(b.id);
        });
      setState(
        () => _catalogue = RewardsCatalogue(
          points: catalogue.points,
          offers: sortedOffers,
        ),
      );
    } catch (_) {
      if (!mounted || request != _catalogueRequest) return;
      setState(
        () => _catalogueError = 'We couldn’t load your points and rewards.',
      );
    } finally {
      if (mounted && request == _catalogueRequest) {
        setState(() => _loadingCatalogue = false);
      }
    }
  }

  Future<void> _loadRedeemed() async {
    final request = ++_redeemedRequest;
    setState(() {
      _loadingRedeemed = true;
      _redeemedError = null;
    });
    try {
      final rewards = await _repository.loadRedeemed();
      if (!mounted || request != _redeemedRequest) return;
      setState(() => _redeemed = rewards);
    } catch (_) {
      if (!mounted || request != _redeemedRequest) return;
      setState(
        () => _redeemedError =
            'We couldn’t load your redeemed rewards. Your saved codes haven’t been changed.',
      );
    } finally {
      if (mounted && request == _redeemedRequest) {
        setState(() => _loadingRedeemed = false);
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadCatalogue(),
      if (_showMine || _redeemed != null) _loadRedeemed(),
    ]);
  }

  void _selectTab(bool mine) {
    if (mine == _showMine) return;
    setState(() => _showMine = mine);
    if (mine) _loadRedeemed();
  }

  void _receiptChanged(RedeemedReward reward) {
    if (!mounted) return;
    setState(
      () => _redeemed = [
        reward,
        ...?_redeemed?.where((entry) => entry.promoCode != reward.promoCode),
      ],
    );
    _loadCatalogue();
    _loadRedeemed();
  }

  RedeemedReward? _activeReceipt(RewardOffer offer) {
    for (final reward in _redeemed ?? <RedeemedReward>[]) {
      if (reward.rewardId == offer.id && !reward.isCollected) return reward;
    }
    return null;
  }

  Color get _cardColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF242321)
      : Colors.white;
  Color get _softColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF302E2B)
      : const Color(0xFFF9F7F3);

  void _showTier() {
    final points = _catalogue!.points;
    final remaining = (2000 - points).clamp(0, 2000);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Active Adventurer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (points / 2000).clamp(0, 1)),
            const SizedBox(height: 12),
            Text('${_number.format(remaining)} pts to Gold Tier'),
            const SizedBox(height: 8),
            const Text(
              'Tier preview · 2,000-point target',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOffer(
    RewardOffer offer, {
    bool openRedemption = false,
    RedeemedReward? receipt,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RewardFlow(
          offer: offer,
          repository: _repository,
          canRedeem:
              !_loadingCatalogue &&
              _catalogueError == null &&
              (_catalogue?.points ?? 0) >= offer.pointsCost,
          redemption: receipt ?? _activeReceipt(offer),
          openRedemption: openRedemption,
          onChanged: _receiptChanged,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
            children: [
              Text(
                'Rewards',
                style: TextStyle(
                  fontSize: 26,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              _wallet(),
              const SizedBox(height: 20),
              _tabs(),
              const SizedBox(height: 18),
              if (_showMine) ..._myRewards() else ..._allRewards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wallet() {
    final points = _catalogue?.points;
    final costs =
        _catalogue?.offers
            .map((r) => r.pointsCost)
            .where((cost) => cost > (points ?? 0))
            .toList() ??
        [];
    costs.sort();
    final nextCost = costs.isEmpty ? null : costs.first;
    final progress = points == null
        ? 0.0
        : nextCost == null
        ? (_catalogue!.offers.isEmpty ? 0.0 : 1.0)
        : (points / nextCost).clamp(0.0, 1.0);
    final caption = _catalogueError != null
        ? 'Points unavailable · pull down to retry'
        : points == null
        ? 'Loading your points…'
        : _catalogue!.offers.isEmpty
        ? 'New rewards are on their way'
        : nextCost == null
        ? 'You have enough points for every reward'
        : '${_number.format(nextCost - points)} pts to your next reward';
    return Semantics(
      button: true,
      label: 'Points wallet. Tap to view tier progress.',
      child: Material(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(22),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        child: InkWell(
          onTap: points == null ? null : _showTier,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POINTS WALLET',
                  style: TextStyle(
                    color: Color(0xFFE1ECF3),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _catalogueError != null
                            ? '—'
                            : points == null
                            ? '…'
                            : _number.format(points),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(
                        text: '   pts',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE1ECF3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(color: Colors.white, height: 1.35),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: Theme.of(context).colorScheme.tertiary,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 5),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE1ECF3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: _softColor,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(children: [_tab('ALL', false), _tab('MY REWARDS', true)]),
  );

  Widget _tab(String title, bool mine) {
    final selected = mine == _showMine;
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? _cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: () => _selectTab(mine),
            borderRadius: BorderRadius.circular(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? colors.onSurface
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _allRewards() {
    if (_loadingCatalogue && _catalogue == null) return [_loader()];
    if (_catalogueError != null) {
      return [_message(_catalogueError!, retry: _loadCatalogue)];
    }
    final offers = _catalogue?.offers ?? [];
    if (offers.isEmpty) {
      return [_message('No rewards available yet. Check back soon.')];
    }
    return offers.map((offer) {
      final canAfford = _catalogue!.points >= offer.pointsCost;
      final redeemed = _activeReceipt(offer) != null;
      return _rewardCard(
        title: offer.title,
        subtitle: offer.partnerName,
        footer: '${_number.format(offer.pointsCost)} pts',
        action: redeemed
            ? 'VIEW REWARD'
            : canAfford
            ? 'REDEEM'
            : 'LOCKED',
        onAction: redeemed || (canAfford && !_loadingCatalogue)
            ? () => _showOffer(offer, openRedemption: !redeemed)
            : null,
        onDetails: () => _showOffer(offer),
      );
    }).toList();
  }

  List<Widget> _myRewards() {
    if (_loadingRedeemed) return [_loader()];
    if (_redeemedError != null) {
      return [_message(_redeemedError!, retry: _loadRedeemed)];
    }
    if (_redeemed == null || _redeemed!.isEmpty) {
      return [
        _message(
          'No redeemed rewards yet. Find your first treat in All rewards.',
          action: 'Browse rewards',
          retry: () async => _selectTab(false),
        ),
      ];
    }
    return _redeemed!
        .map(
          (reward) => _rewardCard(
            title: reward.title,
            subtitle: reward.partnerName ?? 'Redeemed reward',
            footer: reward.isCollected ? 'Collected' : 'Ready to collect',
            action: 'VIEW REWARD',
            footerColor: reward.isCollected
                ? Theme.of(context).colorScheme.tertiary
                : null,
            buttonColor: Theme.of(context).colorScheme.tertiary,
            onAction: () => _showOffer(reward.detailsOffer, receipt: reward),
            onDetails: () => _showOffer(reward.detailsOffer, receipt: reward),
          ),
        )
        .toList();
  }

  Widget _loader() => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _message(
    String text, {
    Future<void> Function()? retry,
    String action = 'Retry',
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (retry != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: retry, child: Text(action)),
        ],
      ],
    ),
  );

  Widget _rewardCard({
    required String title,
    required String subtitle,
    required String footer,
    required String action,
    required VoidCallback? onAction,
    required VoidCallback onDetails,
    Color? footerColor,
    Color? buttonColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: RewardImagePlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 32),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final label = Text(
                            footer,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: footerColor ?? colors.primary,
                            ),
                          );
                          final button = TextButton(
                            onPressed: onAction,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: onAction == null
                                  ? _softColor
                                  : buttonColor ?? colors.primary,
                              disabledForegroundColor: colors.onSurfaceVariant,
                              minimumSize: const Size(96, 28),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(action),
                          );
                          if (constraints.maxWidth < 175 ||
                              MediaQuery.textScalerOf(context).scale(12) > 16) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label,
                                const SizedBox(height: 4),
                                button,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: label),
                              const SizedBox(width: 4),
                              button,
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
