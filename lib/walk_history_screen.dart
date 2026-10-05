import 'vitail_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'activity_history_data.dart';
import 'activity_history_widgets.dart';
import 'vitail_loading.dart';

class WalkHistoryScreen extends StatefulWidget {
  const WalkHistoryScreen({super.key, this.initialDate, this.repository});
  final DateTime? initialDate;
  final ActivityHistoryRepository? repository;
  @override
  State<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends State<WalkHistoryScreen> {
  late DateTime _selected = activityDay(widget.initialDate ?? DateTime.now());
  HistoryPeriod _period = HistoryPeriod.days;
  List<ActivityWalk> _walks = [];
  List<ActivityCoupon> _coupons = [];
  bool _loading = true;
  bool _walkFailed = false;
  bool _couponFailed = false;
  String _filter = 'All activity';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _walkFailed = false;
      _couponFailed = false;
    });
    final repository = widget.repository ?? ActivityHistoryRepository();
    await Future.wait([
      (() async {
        try {
          final walks = await repository.loadWalks();
          if (mounted) setState(() => _walks = walks);
        } catch (_) {
          if (mounted) setState(() => _walkFailed = true);
        }
      })(),
      (() async {
        try {
          final coupons = await repository.loadCoupons();
          if (mounted) setState(() => _coupons = coupons);
        } catch (_) {
          if (mounted) setState(() => _couponFailed = true);
        }
      })(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  void _showFilter() => showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Show activity',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final filter in ['All activity', 'Walks', 'Coupons'])
            ListTile(
              title: Text(filter),
              trailing: _filter == filter ? const VitailIcon('check') : null,
              onTap: () {
                setState(() => _filter = filter);
                Navigator.pop(sheet);
              },
            ),
        ],
      ),
    ),
  );
  void _movePeriod(int direction) {
    final next = switch (_period) {
      HistoryPeriod.days => DateTime(
        _selected.year,
        _selected.month,
        _selected.day + direction,
      ),
      HistoryPeriod.weeks => DateTime(
        _selected.year,
        _selected.month,
        _selected.day + 7 * direction,
      ),
      HistoryPeriod.months => DateTime(
        _selected.year,
        _selected.month + direction,
      ),
    };
    if (!next.isAfter(activityDay(DateTime.now()))) {
      setState(() => _selected = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final walks = _walks
        .where((w) => inActivityPeriod(w.date, _selected, _period))
        .toList();
    final coupons = _coupons
        .where(
          (c) =>
              c.date != null && inActivityPeriod(c.date!, _selected, _period),
        )
        .toList();
    return Scaffold(
      backgroundColor: activityBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const VitailIcon('chevron-left', size: 24),
                  ),
                  IconButton(
                    tooltip: 'Filter activity',
                    onPressed: _showFilter,
                    icon: const VitailIcon('sliders-horizontal', size: 24),
                  ),
                ],
              ),
              const Center(
                child: Text(
                  'History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 46,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F3),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Row(
                  children: [
                    for (final period in HistoryPeriod.values)
                      Expanded(
                        child: Material(
                          color: _period == period
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(21),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(21),
                            onTap: () => setState(() => _period = period),
                            child: Center(
                              child: Text(
                                period.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _period == period
                                      ? const Color(0xFF211F1D)
                                      : activityMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ActivityDateStrip(
                selected: _selected,
                walks: _walks,
                compact: true,
                onChanged: (date) => setState(() => _selected = date),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous period',
                    onPressed: () => _movePeriod(-1),
                    icon: const VitailIcon('chevron-left', size: 18),
                  ),
                  TextButton(
                    onPressed: () => pickActivityDate(
                      context,
                      _selected,
                      (date) => setState(() => _selected = date),
                    ),
                    child: Text(
                      DateFormat(
                        _period == HistoryPeriod.months
                            ? 'MMMM yyyy'
                            : 'd MMM yyyy',
                      ).format(_selected),
                      style: const TextStyle(
                        fontSize: 11,
                        color: activityMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next period',
                    onPressed: _selected == activityDay(DateTime.now())
                        ? null
                        : () => _movePeriod(1),
                    icon: const VitailIcon('chevron-right', size: 18),
                  ),
                ],
              ),
              if (_loading)
                const Center(child: VitailLoading())
              else ...[
                if (_filter != 'Coupons') ...[
                  const ActivitySectionLabel('WALKS'),
                  if (_walkFailed)
                    _retry('Could not load walks.')
                  else if (walks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Text(
                        'No walks in this period.',
                        style: TextStyle(fontSize: 12, color: activityMuted),
                      ),
                    )
                  else
                    for (final walk in walks)
                      ActivityWalkCard(walk: walk, showDog: true),
                ],
                if (_filter != 'Walks') ...[
                  const SizedBox(height: 8),
                  const ActivitySectionLabel('COUPONS'),
                  if (_couponFailed)
                    _retry('Could not load coupons.')
                  else if (coupons.isEmpty)
                    const Text(
                      'No coupons in this period.',
                      style: TextStyle(fontSize: 12, color: activityMuted),
                    )
                  else
                    for (final coupon in coupons) _couponCard(coupon),
                  if (_coupons.any((coupon) => coupon.date == null))
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Older coupons without a recorded date cannot be shown by period.',
                        style: TextStyle(fontSize: 11, color: activityMuted),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _retry(String message) => Row(
    children: [
      Expanded(child: Text(message)),
      TextButton(onPressed: _load, child: const Text('Retry')),
    ],
  );
  Widget _couponCard(ActivityCoupon coupon) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: activityShadow,
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF9F7F3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coupon.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                coupon.details,
                style: const TextStyle(fontSize: 11, color: activityMuted),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: coupon.collected
                      ? const Color(0xFFEAF0D8)
                      : const Color(0xFFF5D6CE),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  coupon.collected ? 'REDEEMED' : 'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: coupon.collected
                        ? const Color(0xFFAEC568)
                        : const Color(0xFFDC755C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
