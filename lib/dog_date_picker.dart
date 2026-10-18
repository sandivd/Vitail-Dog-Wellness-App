import 'vitail_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

Future<DateTime?> showDogDatePicker(
  BuildContext context, {
  DateTime? initialDate,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: VitailColors.of(context).background,
    barrierColor: const Color(0x52211F1C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => DogDatePicker(initialDate: initialDate),
  );
}

class DogDatePicker extends StatefulWidget {
  const DogDatePicker({super.key, this.initialDate, this.today});
  final DateTime? initialDate;
  final DateTime? today;
  @override
  State<DogDatePicker> createState() => _DogDatePickerState();
}

class _DogDatePickerState extends State<DogDatePicker> {
  VitailColors get colors => VitailColors.of(context);

  Color get ink => colors.tint(const Color(0xFF241C24), colors.ink);
  Color get border => colors.tint(const Color(0xFFDAD6CD), colors.border);

  late DateTime today, month;
  DateTime? selected;
  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    final initial = widget.initialDate;
    selected =
        initial != null && initial.year >= 2000 && !initial.isAfter(today)
        ? DateTime(initial.year, initial.month, initial.day)
        : null;
    month = DateTime((selected ?? today).year, (selected ?? today).month);
  }

  TextStyle style(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) => TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: size,
    fontWeight: weight,
    color: color ?? ink,
  );

  Widget selector(bool year) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: colors.card,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        key: ValueKey(year ? 'year-selector' : 'month-selector'),
        value: year ? month.year : month.month,
        isExpanded: true,
        dropdownColor: colors.card,
        borderRadius: BorderRadius.circular(14),
        menuMaxHeight: 320,
        style: style(14),
        icon: SvgPicture.asset(
          'assets/icons/onboarding-chevron.svg',
          width: 24,
          height: 24,
          colorFilter: colors.isDark
              ? ColorFilter.mode(colors.muted, BlendMode.srcIn)
              : null,
        ),
        items: [
          for (final value
              in year
                  ? List.generate(today.year - 1999, (i) => today.year - i)
                  : List.generate(
                      month.year == today.year ? today.month : 12,
                      (i) => i + 1,
                    ))
            DropdownMenuItem(
              value: value,
              child: Text(
                year
                    ? '$value'
                    : DateFormat.MMMM().format(DateTime(2000, value)),
              ),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            final y = year ? value : month.year;
            final m = year
                ? (y == today.year && month.month > today.month
                      ? today.month
                      : month.month)
                : value;
            month = DateTime(y, m);
          });
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((offset + count) / 7).ceil();
    return Material(
      color: colors.background,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Date of birth', style: style(22, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'When was your dog born?',
                style: style(13, color: colors.muted, weight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: selector(false)),
                  const SizedBox(width: 12),
                  Expanded(child: selector(true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(
                        child: Text(day, style: style(11, color: colors.muted)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (var week = 0; week < rows; week++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day = week * 7 + column - offset + 1;
                            if (day < 1 || day > count) {
                              return const SizedBox(height: 44);
                            }
                            final date = DateTime(month.year, month.month, day);
                            final enabled = !date.isAfter(today);
                            final active = date == selected;
                            return Semantics(
                              selected: active,
                              label: DateFormat.yMMMMd().format(date),
                              child: TextButton(
                                key: ValueKey('day-$day'),
                                onPressed: enabled
                                    ? () => setState(() => selected = date)
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(40, 44),
                                  backgroundColor: active
                                      ? colors.green
                                      : Colors.transparent,
                                  shape: const CircleBorder(),
                                ),
                                child: Text(
                                  '$day',
                                  style: style(
                                    13,
                                    color: active
                                        ? colors.tint(
                                            Colors.white,
                                            const Color(0xFF211F1D),
                                          )
                                        : enabled
                                        ? ink
                                        : border,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                selected == null
                    ? 'Select a date'
                    : 'Selected: ${DateFormat('d MMMM yyyy').format(selected!)}',
                style: style(13, color: colors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: colors.card,
                        side: BorderSide(color: border),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text('Cancel', style: style(14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(context, selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.green,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: Text(
                        'Confirm date',
                        style: style(
                          14,
                          color: selected == null
                              ? colors.muted
                              : colors.tint(
                                  Colors.white,
                                  const Color(0xFF211F1D),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
