import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dog_sharing.dart';

DateTime activityDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

enum HistoryPeriod { days, weeks, months }

bool inActivityPeriod(DateTime date, DateTime selected, HistoryPeriod period) {
  final day = activityDay(date);
  final anchor = activityDay(selected);
  switch (period) {
    case HistoryPeriod.days:
      return day == anchor;
    case HistoryPeriod.weeks:
      final start = DateTime(
        anchor.year,
        anchor.month,
        anchor.day - anchor.weekday + 1,
      );
      return !day.isBefore(start) &&
          day.isBefore(DateTime(start.year, start.month, start.day + 7));
    case HistoryPeriod.months:
      return day.year == anchor.year && day.month == anchor.month;
  }
}

class ActivityWalk {
  ActivityWalk(this.row, {this.dog});
  final Map<String, dynamic> row;
  final Map<String, dynamic>? dog;
  DateTime get date => DateTime.parse(row['walk_date'].toString()).toLocal();
  DateTime? get timestamp => DateTime.tryParse(
    (row['started_at'] ?? row['created_at'] ?? '').toString(),
  )?.toLocal();
  double get meters => (row['distance_meters'] as num?)?.toDouble() ?? 0;
  int get seconds => (row['duration_seconds'] as num?)?.toInt() ?? 0;
  int get points => (row['points_earned'] as num?)?.toInt() ?? 0;
  String get title {
    final name = row['title']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final hour = timestamp?.hour;
    if (hour == null) return 'Walk';
    if (hour < 5 || hour >= 20) return 'Night walk';
    if (hour < 12) return 'Morning walk';
    if (hour < 17) return 'Afternoon walk';
    return 'Evening walk';
  }

  String get details => [
    if (timestamp != null) DateFormat('HH:mm').format(timestamp!),
    '${seconds ~/ 60} min',
    '${(meters / 1000).toStringAsFixed(1)} km',
  ].join(' · ');
}

class ActivityCoupon {
  ActivityCoupon(this.row);
  final Map<String, dynamic> row;
  DateTime? get date => DateTime.tryParse(
    (row['redeemed_at'] ?? row['created_at'] ?? '').toString(),
  )?.toLocal();
  String get title => row['reward_title']?.toString() ?? 'Reward';
  bool get collected => row['is_collected'] == true;
  String get details => [
    if (row['partner_name'] != null) row['partner_name'].toString(),
    if (row['points_cost'] != null) '${row['points_cost']} pts',
  ].join(' · ');
}

class ActivityHistoryRepository {
  Future<List<ActivityWalk>> loadWalks() async {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view activity.');
    final link = await primaryDogForCurrentUser();
    final dogId = link?.dog['id']?.toString();
    final rows = await client
        .from('walks')
        .select()
        .or(walksVisibleFilter(id, dogId))
        .order('walk_date', ascending: false);
    final byId = {if (dogId != null) dogId: link!.dog};
    final walks = [
      for (final row in rows)
        ActivityWalk(row, dog: byId[row['dog_id']?.toString()]),
    ];
    walks.sort(
      (a, b) => (b.timestamp ?? b.date).compareTo(a.timestamp ?? a.date),
    );
    return walks;
  }

  Future<List<ActivityCoupon>> loadCoupons() async {
    final client = Supabase.instance.client;
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view activity.');
    final rows = await client
        .from('reward_receipts')
        .select()
        .eq('user_id', id);
    return [for (final row in rows) ActivityCoupon(row)]..sort(
      (a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)),
    );
  }
}
