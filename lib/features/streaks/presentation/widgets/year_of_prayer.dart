import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../domain/prayer_day.dart';

/// The whole year, one small dot per day.
///
/// Weeks run left to right, Monday to Sunday down each column, so the year
/// reads like a strip of film: a green stretch is a run of good weeks, a
/// rose fleck is a day a prayer was missed, a gold halo is a night of
/// Tahajjud. Tap a dot — or slide a finger across the year — to open that
/// day below. Future days are drawn faint and cannot be selected.
class YearOfPrayer extends StatelessWidget {
  const YearOfPrayer({
    super.key,
    required this.history,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final StreakHistory history;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  void _pick(Offset at, _YearGrid grid) {
    final DateTime? day = grid.dateAt(at);
    if (day == null || day.isAfter(today) || day == selected) return;
    HapticFeedback.selectionClick();
    onSelect(day);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _YearGrid grid = _YearGrid(history.year, constraints.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _pick(d.localPosition, grid),
          // Horizontal only, so the page still scrolls when a finger moves
          // up or down across the dots.
          onHorizontalDragStart: (DragStartDetails d) =>
              _pick(d.localPosition, grid),
          onHorizontalDragUpdate: (DragUpdateDetails d) =>
              _pick(d.localPosition, grid),
          child: CustomPaint(
            size: Size(constraints.maxWidth, grid.height),
            painter: _YearPainter(
              grid: grid,
              history: history,
              today: Fmt.dayStart(today),
              selected: selected,
            ),
          ),
        );
      },
    );
  }
}

/// What the dots mean.
class YearLegend extends StatelessWidget {
  const YearLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppType.bodySm.copyWith(
      fontSize: 10,
      color: AppColors.mistFaint,
    );
    return Wrap(
      spacing: Insets.md,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _Key(style: style, label: 'none', fill: AppColors.navyLine),
        _Key(
          style: style,
          label: 'some',
          fill: Color.lerp(AppColors.emeraldDeep, AppColors.emerald, 0.5)!,
        ),
        _Key(style: style, label: 'all five', fill: AppColors.emerald),
        _Key(
          style: style,
          label: 'missed',
          fill: AppColors.rose.withValues(alpha: 0.55),
        ),
        _Key(
          style: style,
          label: 'Tahajjud',
          fill: AppColors.navyLine,
          ring: AppColors.goldSoft,
        ),
        _Key(
          style: style,
          label: 'today',
          fill: AppColors.navyLine,
          ring: AppColors.gold,
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.style,
    required this.label,
    required this.fill,
    this.ring,
  });

  final TextStyle style;
  final String label;
  final Color fill;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: ring == null ? null : Border.all(color: ring!, width: 1.2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}

/// The geometry of one year laid out in week columns, shared by painting
/// and hit-testing so a finger lands on the dot it is over.
class _YearGrid {
  _YearGrid(this.year, double width)
    : lead = DateTime(year, 1, 1).weekday - 1,
      days = DateTime.utc(
        year + 1,
        1,
        1,
      ).difference(DateTime.utc(year, 1, 1)).inDays {
    columns = (lead + days + 6) ~/ 7;
    cell = width / columns;
  }

  /// Room above the dots for the month initials.
  static const double labelBand = 16;

  final int year;

  /// Empty slots before 1 January in the first column (0 for a Monday).
  final int lead;
  final int days;
  late final int columns;
  late final double cell;

  double get height => labelBand + cell * 7;

  DateTime dateOf(int i) => DateTime(year, 1, 1 + i);

  /// Day-of-year, or null when [d] is not in this year. Computed in UTC so a
  /// daylight-saving hour cannot shave a day off the count.
  int? indexOf(DateTime d) {
    if (d.year != year) return null;
    return DateTime.utc(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.utc(year, 1, 1)).inDays;
  }

  Offset centerOf(int i) {
    final int slot = lead + i;
    return Offset(
      (slot ~/ 7) * cell + cell / 2,
      labelBand + (slot % 7) * cell + cell / 2,
    );
  }

  DateTime? dateAt(Offset p) {
    if (p.dy < labelBand) return null;
    final int col = (p.dx / cell).floor();
    final int row = ((p.dy - labelBand) / cell).floor();
    if (col < 0 || col >= columns || row < 0 || row > 6) return null;
    final int i = col * 7 + row - lead;
    if (i < 0 || i >= days) return null;
    return dateOf(i);
  }
}

class _YearPainter extends CustomPainter {
  _YearPainter({
    required this.grid,
    required this.history,
    required this.today,
    required this.selected,
  });

  final _YearGrid grid;
  final StreakHistory history;
  final DateTime today;
  final DateTime? selected;

  static const String _initials = 'JFMAMJJASOND';

  @override
  void paint(Canvas canvas, Size size) {
    final double r = grid.cell * 0.34;
    final Paint fill = Paint();
    final Paint ring = Paint()..style = PaintingStyle.stroke;

    // Month initials, over the column each month begins in.
    final TextStyle labelStyle = AppType.label.copyWith(
      fontSize: 9,
      color: AppColors.mistFaint,
    );
    for (int m = 1; m <= 12; m++) {
      final int i = grid.indexOf(DateTime(grid.year, m, 1))!;
      final TextPainter tp = TextPainter(
        text: TextSpan(text: _initials[m - 1], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(((grid.lead + i) ~/ 7) * grid.cell, 0));
    }

    final int? todayIndex = grid.indexOf(today);
    final int? selectedIndex = selected == null
        ? null
        : grid.indexOf(selected!);

    for (int i = 0; i < grid.days; i++) {
      final DateTime date = grid.dateOf(i);
      final Offset c = grid.centerOf(i);
      final bool future = date.isAfter(today);
      final PrayerDay day = history.dayFor(Fmt.dayId(date));

      fill.color = _dotColor(day, future: future);
      canvas.drawCircle(c, r, fill);

      if (day.tahajjudPrayed) {
        ring
          ..color = AppColors.goldSoft
          ..strokeWidth = 1;
        canvas.drawCircle(c, r + 1.1, ring);
      }
      if (i == todayIndex) {
        ring
          ..color = AppColors.gold
          ..strokeWidth = 1.2;
        canvas.drawCircle(c, r + 1.7, ring);
      }
      if (i == selectedIndex) {
        fill.color = AppColors.goldSoft.withValues(alpha: 0.22);
        canvas.drawCircle(c, r + 6, fill);
        ring
          ..color = AppColors.cream
          ..strokeWidth = 1.4;
        canvas.drawCircle(c, r + 3, ring);
      }
    }
  }

  Color _dotColor(PrayerDay day, {required bool future}) {
    if (future) return AppColors.navyLine.withValues(alpha: 0.4);
    final int n = day.completedCount;
    final int all = PrayerId.obligatory.length;
    if (n >= all) return AppColors.emerald;
    if (n > 0) {
      return Color.lerp(AppColors.emeraldDeep, AppColors.emerald, n / all)!;
    }
    if (day.anyMissed) return AppColors.rose.withValues(alpha: 0.55);
    return AppColors.navyLine;
  }

  @override
  bool shouldRepaint(_YearPainter old) =>
      old.selected != selected ||
      old.history != history ||
      old.today != today ||
      old.grid.cell != grid.cell;
}
