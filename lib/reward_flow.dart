import 'vitail_colors.dart';
import 'vitail_icon.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'check_in_screen.dart';
import 'reward_details_screen.dart';
import 'reward_image_placeholder.dart';
import 'rewards_data.dart';
import 'vitail_snack.dart';
import 'reward_venues.dart';
import 'venue_detail.dart';

class RewardFlow extends StatefulWidget {
  const RewardFlow({
    super.key,
    required this.offer,
    required this.repository,
    required this.canRedeem,
    required this.onChanged,
    this.redemption,
    this.openRedemption = false,
    this.venueLoader = loadRewardVenues,
    this.catalogue,
    this.receipts = const [],
  });
  final Future<List<VenueInfo>> Function() venueLoader;
  final RewardsCatalogue? catalogue;
  final List<RedeemedReward> receipts;
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
  late RewardOffer _selectedOffer = widget.offer;
  late int? _points = widget.catalogue?.points;
  late final Map<String, RedeemedReward> _receipts = {
    for (final receipt in widget.receipts)
      if (receipt.rewardId != null && !receipt.isCollected)
        receipt.rewardId!: receipt,
    if (widget.redemption != null) widget.offer.id: widget.redemption!,
  };
  RedeemedReward? get _reward => _receipts[_selectedOffer.id];
  List<RewardOffer> _offers = [];
  final Map<String, String> _requestIds = {};
  String get _requestId => _requestIds.putIfAbsent(
    _selectedOffer.id,
    () => List.generate(
      24,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(),
  );
  bool _canRedeem(RewardOffer offer) =>
      (widget.catalogue?.canRedeem ?? widget.canRedeem) &&
      (_points != null
          ? _points! >= offer.pointsCost
          : offer.id == widget.offer.id && widget.canRedeem);
  final _progress = ValueNotifier<String?>(null);
  VenueInfo? _venue;
  LatLng? _userLocation;

  Future<void> _loadDistance() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        setState(
          () => _userLocation = LatLng(position.latitude, position.longitude),
        );
      }
    } catch (_) {
      // Venue navigation remains available without location access.
    }
  }

  bool _loadingVenue = true;
  bool _venueFailed = false;

  Future<void> _loadVenue() async {
    setState(() {
      _loadingVenue = true;
      _venueFailed = false;
    });
    try {
      final venues = await widget.venueLoader();
      if (!mounted) return;
      setState(() {
        _venue = venueForReward(widget.offer, venues);
        _offers = [
          for (final offer in widget.catalogue?.offers ?? [widget.offer])
            if (_venue != null &&
                identical(venueForReward(offer, venues), _venue))
              offer,
        ];
        if (!_offers.any((offer) => offer.id == widget.offer.id)) {
          _offers.add(widget.offer);
        }
        _offers.sort((a, b) {
          final cost = a.pointsCost.compareTo(b.pointsCost);
          return cost != 0 ? cost : a.id.compareTo(b.id);
        });
      });
    } catch (_) {
      if (mounted) setState(() => _venueFailed = true);
    } finally {
      if (mounted) setState(() => _loadingVenue = false);
    }
  }

  void _goHere() {
    final venue = _venue;
    if (venue == null) {
      _loadVenue();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (venueContext) => VenueDetailScreen(
          venue: venue,
          userLocation: _userLocation,
          onCheckRewards: () => Navigator.pop(venueContext),
        ),
      ),
    );
  }

  bool _busy = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _loadVenue();
    _loadDistance();
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
    if (_busy || _reward != null || !_canRedeem(_selectedOffer)) return;
    final offer = _selectedOffer;
    _busy = true;
    _progress.value = 'busy';
    try {
      final reward = await widget.repository.redeem(offer, _requestId);
      // Update the catalogue even if this route or its sheet was dismissed.
      widget.onChanged(reward);
      if (!mounted) return;
      setState(() {
        _receipts[offer.id] = reward;
        if (_points != null) {
          _points = (_points! - offer.pointsCost).clamp(0, 1 << 53);
        }
      });
      _progress.value = 'success';
    } catch (_) {
      if (mounted) {
        _progress.value =
            'We couldn’t confirm redemption. Please retry. You won’t be charged twice for this request.';
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      } else {
        _busy = false;
      }
    }
  }

  Future<void> _showRedemption() async {
    if (_sheetOpen || _reward != null || !_canRedeem(_selectedOffer)) return;
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
                        icon: const VitailIcon('x', size: 24),
                      ),
                    ),
                    if (success)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VitailColors.of(sheetContext).tint(
                            const Color(0xFFF2F6E7),
                            VitailColors.of(sheetContext).greenPale,
                          ),
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
                      success ? 'Redeemed!' : _selectedOffer.title,
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
                          : '${NumberFormat.decimalPattern('en').format(_selectedOffer.pointsCost)} points',
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
    final offerId = _selectedOffer.id;
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
            if (mounted) setState(() => _receipts[offerId] = collected);
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
              showVitailSnack(
                context,
                'Code copied to clipboard!',
                type: VitailSnackType.success,
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
    venue: _venue,
    distanceLabel: _venue?.distanceLabelFrom(_userLocation),
    onGoHere: _loadingVenue ? null : _goHere,
    venueStatus: _loadingVenue
        ? 'Loading venue…'
        : _venueFailed
        ? 'Could not load the venue. Tap GO HERE to retry.'
        : _venue == null
        ? 'No linked venue available yet. Tap GO HERE to refresh.'
        : null,
    offerCards: [
      for (final offer in _offers.isEmpty ? [widget.offer] : _offers)
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: RewardOfferCard(
            key: ValueKey('offer-${offer.id}'),
            offer: offer,
            canRedeem: !_busy && _canRedeem(offer),
            lockedMessage: widget.catalogue?.canRedeem == false
                ? RewardOfferCard.microchipLockedMessage
                : RewardOfferCard.insufficientPointsMessage,
            redemption: _receipts[offer.id],
            onRedeem: () {
              if (_busy || _sheetOpen) return;
              _selectedOffer = offer;
              _progress.value = null;
              _showRedemption();
            },
            onCheckIn: () {
              if (_busy || _sheetOpen) return;
              _selectedOffer = offer;
              _checkIn();
            },
            onShowCode: () {
              if (_busy || _sheetOpen) return;
              _selectedOffer = offer;
              _showCode();
            },
          ),
        ),
    ],
    canRedeem: _canRedeem(widget.offer),
    onRedeem: _showRedemption,
    redemption: _reward,
    onCheckIn: _checkIn,
    onShowCode: _showCode,
  );
}
