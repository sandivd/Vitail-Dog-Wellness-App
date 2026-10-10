import 'microchip_screen.dart';
import 'vitail_loading.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'reward_flow.dart';
import 'reward_venues.dart';
import 'rewards_data.dart';
import 'venue_detail.dart';
import 'venue_reward_thumbnail.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({
    super.key,
    this.repository,
    this.isActive = true,
    this.partnerId,
    this.venueName,
    this.venueLoader = loadRewardVenues,
  });

  final Future<List<VenueInfo>> Function() venueLoader;
  final RewardsRepository? repository;
  final bool isActive;
  final String? partnerId;
  final String? venueName;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  late final RewardsRepository _repository;
  RewardsCatalogue? _catalogue;
  List<VenueInfo> _venues = [];
  List<RedeemedReward>? _redeemed;
  bool _showMine = false;
  bool _loadingCatalogue = true;
  bool _loadingRedeemed = false;
  String? _catalogueError;
  String? _redeemedError;
  int _catalogueRequest = 0;
  int _redeemedRequest = 0;
  final _number = NumberFormat.decimalPattern('en');

  /// Full-screen branded loader only while the first catalogue load is in
  /// flight; later refreshes and redeemed-rewards loads keep the visible UI.
  bool get _isLoading => _loadingCatalogue && _catalogue == null;

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
      List<VenueInfo> venues;
      try {
        venues = await widget.venueLoader();
      } catch (_) {
        if (widget.partnerId != null) rethrow;
        venues = []; // Photo failures must not hide the rewards catalogue.
      }
      if (!mounted || request != _catalogueRequest) return;
      final sortedOffers =
          List<RewardOffer>.of(
            catalogue.offers.where(
              (offer) =>
                  widget.partnerId == null ||
                  venueForReward(offer, venues)?.partnerId == widget.partnerId,
            ),
          )..sort((a, b) {
            final costOrder = a.pointsCost.compareTo(b.pointsCost);
            return costOrder != 0 ? costOrder : a.id.compareTo(b.id);
          });
      _venues = venues;
      setState(
        () => _catalogue = RewardsCatalogue(
          points: catalogue.points,
          canRedeem: catalogue.canRedeem,
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
          offer:
              (_catalogue?.offers
                  .where((entry) => entry.id == offer.id)
                  .firstOrNull) ??
              offer,
          repository: _repository,
          catalogue: _catalogue,
          receipts: _redeemed ?? [],
          venueLoader: widget.venueLoader,
          canRedeem:
              (_catalogue?.canRedeem ?? false) &&
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: VitailLoading()));
    }

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
              if (_catalogue != null && !_catalogue!.canRedeem) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_outline),
                        const SizedBox(height: 8),
                        const Text(
                          'Unlock rewards',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a valid microchip number to redeem rewards. You can keep tracking walks and earning points while rewards are locked.',
                        ),
                        TextButton(
                          onPressed: _loadingCatalogue
                              ? null
                              : () async {
                                  await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MicrochipScreen(
                                        isFromProfile: true,
                                      ),
                                    ),
                                  );
                                  if (mounted) await _refresh();
                                },
                          child: const Text('Verify microchip'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POINTS WALLET',
                  style: TextStyle(
                    color: Color(0xFFE1ECF3),
                    fontSize: 12,
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
                          fontSize: 16,
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
                    fontSize: 13,
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
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
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
      final canAfford =
          _catalogue!.canRedeem && _catalogue!.points >= offer.pointsCost;
      final redeemed = _activeReceipt(offer) != null;
      return _rewardCard(
        title: offer.title,
        photoUrl: venueForReward(offer, _venues)?.photoUrl,
        subtitle: offer.partnerName,
        footer: '${_number.format(offer.pointsCost)} pts',
        isPointsCost: true,
        buttonColor: redeemed ? Theme.of(context).colorScheme.tertiary : null,
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
            photoUrl: venueForReward(
              _catalogue?.offers
                      .where((offer) => offer.id == reward.rewardId)
                      .firstOrNull ??
                  reward.detailsOffer,
              _venues,
            )?.photoUrl,
            subtitle: reward.partnerName ?? 'Redeemed reward',
            footer: reward.isCollected ? 'Collected' : 'Ready to collect',
            action: 'VIEW REWARD',
            footerColor: reward.isCollected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
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
    bool isPointsCost = false,
    String? photoUrl,
    Color? footerColor,
    Color? buttonColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: VenueRewardThumbnail(photoUrl: photoUrl),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 32),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
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
                              fontSize: isPointsCost ? 14 : 12,
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
                              minimumSize: const Size(96, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: Text(action),
                          );
                          if (constraints.maxWidth < 200 ||
                              MediaQuery.textScalerOf(context).scale(14) > 18) {
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
