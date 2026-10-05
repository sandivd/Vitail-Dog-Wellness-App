import 'vitail_icon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'activity_history_data.dart';
import 'walk_summary.dart';

const activityBackground = Color(0xFFF4F0E9);
const activityMuted = Color(0xFF6E6A63);
const activityBlue = Color(0xFF5F98BD);
const activityShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3)),
];

class ActivityDateStrip extends StatefulWidget {
  const ActivityDateStrip({
    super.key,
    required this.selected,
    required this.onChanged,
    this.walks = const [],
    this.compact = false,
  });
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final List<ActivityWalk> walks;
  final bool compact;
  @override
  State<ActivityDateStrip> createState() => _ActivityDateStripState();
}

class _ActivityDateStripState extends State<ActivityDateStrip> {
  late final DateTime _today = activityDay(DateTime.now());
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _index(widget.selected) * _extent,
  );
  double get _extent => widget.compact ? 58 : 64;
  int _index(DateTime date) =>
      DateTime.utc(_today.year, _today.month, _today.day)
          .difference(DateTime.utc(date.year, date.month, date.day))
          .inDays
          .clamp(0, _dayCount - 1);
  int get _dayCount =>
      DateTime.utc(
        _today.year,
        _today.month,
        _today.day,
      ).difference(DateTime.utc(2000)).inDays +
      1;

  @override
  void didUpdateWidget(ActivityDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (activityDay(oldWidget.selected) != activityDay(widget.selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final target = _index(widget.selected) * _extent;
        final position = _scroll.position;
        if (target < position.pixels ||
            target + _extent - 8 >
                position.pixels + position.viewportDimension) {
          _scroll.animateTo(
            target.clamp(0, position.maxScrollExtent),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.compact ? 64 : 68,
    child: Row(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                ...ScrollConfiguration.of(context).dragDevices,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.separated(
              key: const ValueKey('activity-date-scroll'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: _dayCount,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => SizedBox(
                width: widget.compact ? 50 : 56,
                child: _day(
                  DateTime(_today.year, _today.month, _today.day - index),
                ),
              ),
            ),
          ),
        ),
        if (widget.compact) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 22,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFDBD7D1)),
              ),
              child: InkWell(
                onTap: () => pickActivityDate(
                  context,
                  widget.selected,
                  widget.onChanged,
                ),
                borderRadius: BorderRadius.circular(14),
                child: const SizedBox(
                  height: 64,
                  child: Center(
                    child: VitailIcon(
                      'calendar',
                      size: 14,
                      color: activityMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _day(DateTime date) {
    final active = activityDay(widget.selected) == date;
    final hasWalk = widget.walks.any((walk) => activityDay(walk.date) == date);
    return Semantics(
      key: ValueKey('activity-day-${DateFormat('yyyy-MM-dd').format(date)}'),
      selected: active,
      button: true,
      label: DateFormat.yMMMMEEEEd().format(date),
      child: Material(
        color: active ? activityBlue : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.compact ? 14 : 16),
          side: BorderSide(
            color: active ? activityBlue : const Color(0xFFDBD7D1),
          ),
        ),
        child: InkWell(
          onTap: () => widget.onChanged(date),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('EEE').format(date).substring(0, 2).toUpperCase(),
                style: TextStyle(
                  fontSize: widget.compact ? 9 : 10,
                  color: active ? Colors.white : activityMuted,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: widget.compact ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : const Color(0xFF211F1D),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 6,
                child: hasWalk
                    ? SvgPicture.asset(
                        'assets/icons/history-day-dot.svg',
                        width: 6,
                        height: 6,
                        colorFilter: ColorFilter.mode(
                          active ? Colors.white : activityBlue,
                          BlendMode.srcIn,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> pickActivityDate(
  BuildContext context,
  DateTime selected,
  ValueChanged<DateTime> onChanged,
) async {
  final now = activityDay(DateTime.now());
  final date = await showDatePicker(
    context: context,
    initialDate: selected.isAfter(now) ? now : selected,
    firstDate: DateTime(2000),
    lastDate: now,
  );
  if (date != null) onChanged(date);
}

class ActivityWalkCard extends StatelessWidget {
  const ActivityWalkCard({super.key, required this.walk, this.showDog = false});
  final ActivityWalk walk;
  final bool showDog;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: activityShadow,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openSavedWalk(context, walk),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (showDog)
                SizedBox(
                  width: 30,
                  height: 30,
                  child: walk.dog?['photo_url'] != null
                      ? ClipOval(
                          child: Image.network(
                            walk.dog!['photo_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => SvgPicture.asset(
                              'assets/icons/history-pet.svg',
                            ),
                          ),
                        )
                      : SvgPicture.asset('assets/icons/history-pet.svg'),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1E8E1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(walk.date).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: activityMuted,
                        ),
                      ),
                      Text(
                        '${walk.date.day}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      walk.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      walk.details,
                      style: const TextStyle(
                        fontSize: 11,
                        color: activityMuted,
                      ),
                    ),
                    if (showDog && walk.dog != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        walk.dog!['dog_name'] ?? 'Dog',
                        style: const TextStyle(
                          fontSize: 11,
                          color: activityMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const VitailIcon('chevron-right', size: 16, color: activityMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

void openSavedWalk(BuildContext context, ActivityWalk walk) {
  final route = walk.row['route_data'];
  final points = <LatLng>[
    if (route is List)
      for (final point in route)
        if (point is Map && point['lat'] is num && point['lng'] is num)
          LatLng(
            (point['lat'] as num).toDouble(),
            (point['lng'] as num).toDouble(),
          ),
  ];
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WalkSummary(
        distanceMeters: walk.meters,
        elapsedSeconds: walk.seconds,
        goalMinutes: (walk.dog?['daily_goal_minutes'] as num?)?.toInt() ?? 60,
        dog: walk.dog,
        hygiene: {
          'pee': walk.row['hygiene_pee'] == true,
          'poo': walk.row['hygiene_poo'] == true,
        },
        routePoints: points,
        initialNote: walk.row['note'] as String?,
        savedWalk: walk.row,
      ),
    ),
  );
}

class ActivitySectionLabel extends StatelessWidget {
  const ActivitySectionLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: activityMuted,
      ),
    ),
  );
}
