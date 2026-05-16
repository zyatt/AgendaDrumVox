// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/show_model.dart';
import '../providers/show_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/show_card.dart';

bool _isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= 900;

bool _isLandscapeMobile(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.size.width >= 550 &&
      mq.size.width < 900 &&
      mq.orientation == Orientation.landscape;
}

int _monthGridColumns(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 1200) return 4;
  if (w >= 900) return 3;
  if (w >= 600) return 3;
  return 2;
}

Widget _centered(Widget child, {double maxWidth = 1100}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAsync = ref.watch(showsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: showsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2,
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 26),
                ),
                const SizedBox(height: 16),
                const Text('Erro ao carregar', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$e', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
              ],
            ),
          ),
          data: (allShows) => _YearOverview(allShows: allShows),
        ),
      ),
    );
  }
}

class _YearOverview extends ConsumerStatefulWidget {
  final List<ShowModel> allShows;
  const _YearOverview({required this.allShows});

  @override
  ConsumerState<_YearOverview> createState() => _YearOverviewState();
}

class _YearOverviewState extends ConsumerState<_YearOverview> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final desktop = _isDesktop(context);

    final yearShows = widget.allShows
        .where((s) => s.showDate.year == _selectedYear)
        .toList();

    final activeYearShows = yearShows.where((s) => !s.cancelled).toList();
    final cancelledYearShows = yearShows.where((s) => s.cancelled).toList();

    final Map<String, List<ShowModel>> byMonth = {};
    for (final show in yearShows) {
      final key = '${show.showDate.year}-${show.showDate.month}';
      byMonth.putIfAbsent(key, () => []).add(show);
    }

    final double totalYear = activeYearShows.fold(0, (sum, s) => sum + s.value);
    final today = DateTime(now.year, now.month, now.day);
    final double earnedYear = activeYearShows
        .where((s) => DateTime(s.showDate.year, s.showDate.month, s.showDate.day).isBefore(today))
        .fold(0, (sum, s) => sum + s.value);
    final double cancelledYear = cancelledYearShows.fold(0, (sum, s) => sum + s.value);

    final upcomingShows = widget.allShows
        .where((s) => !s.cancelled && !DateTime(s.showDate.year, s.showDate.month, s.showDate.day).isBefore(today))
        .toList()
      ..sort((a, b) => a.showDate.compareTo(b.showDate));
    final nextShows = upcomingShows.take(5).toList();

    final hPad = desktop ? 32.0 : 16.0;
    final screenWidth = MediaQuery.of(context).size.width;

    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: _centered(
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad - 4, 4),
              child: Row(
                children: [
                  Image.asset(
                    'assets/drumvoxduo.png',
                    height: screenWidth < 360 ? 40 : screenWidth < 600 ? 55 : 70,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  _YearSelector(
                    selectedYear: _selectedYear,
                    onPrev: () => setState(() => _selectedYear--),
                    onNext: () => setState(() => _selectedYear++),
                    onTap: () => _pickYear(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => ref.read(showsProvider.notifier).refresh(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Resumo anual ──
        SliverToBoxAdapter(
          child: _centered(
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
              child: _YearSummaryCard(
                selectedYear: _selectedYear,
                totalYear: totalYear,
                earnedYear: earnedYear,
                cancelledYear: cancelledYear,
                showCount: activeYearShows.length,
                now: now,
                desktop: desktop,
              ),
            ),
          ),
        ),

        // ── Próximas datas ──
        if (nextShows.isNotEmpty)
          SliverToBoxAdapter(
            child: _centered(
              _UpcomingShowsCard(
                nextShows: nextShows,
                today: today,
                desktop: desktop,
                hPad: hPad,
              ),
            ),
          ),

        // ── Seção grid ──
        SliverToBoxAdapter(
          child: _centered(
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 8),
              child: Row(
                children: [
                  const Text(
                    'MESES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, color: AppTheme.border)),
                ],
              ),
            ),
          ),
        ),

        // ── Grid 12 meses ──
        SliverToBoxAdapter(
          child: _centered(
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _monthGridColumns(context);
                  final spacing = desktop ? 14.0 : 10.0;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (cols - 1)) / cols;

                  int maxShows = 0;
                  for (int m = 1; m <= 12; m++) {
                    final key = '$_selectedYear-$m';
                    final count = (byMonth[key] ?? []).where((s) => !s.cancelled).length;
                    if (count > maxShows) maxShows = count;
                  }

                  const double bubbleSize = 24;
                  const double bubbleSpacing = 3;
                  const int bubblesPerRow = 4;
                  final int bubbleRows = maxShows == 0
                      ? 1
                      : ((maxShows + bubblesPerRow - 1) ~/ bubblesPerRow);
                  final double padding = desktop ? 15.0 : 12.0;
                  final double headerH = (desktop ? 14.0 : 13.0) + 8;
                  final double bubblesH = maxShows == 0
                      ? (12 + 12 + 12)
                      : (bubbleRows * bubbleSize + (bubbleRows - 1) * bubbleSpacing);
                  final double footerH = maxShows == 0 ? 0 : (8 + 14);
                  final double cardHeight = padding * 2 + headerH + bubblesH + footerH + 4;

                  final List<Widget> rows = [];
                  for (int rowStart = 0; rowStart < 12; rowStart += cols) {
                    final rowChildren = <Widget>[];
                    for (int c = 0; c < cols; c++) {
                      final index = rowStart + c;
                      if (c > 0) rowChildren.add(SizedBox(width: spacing));
                      if (index < 12) {
                        final month = index + 1;
                        final key = '$_selectedYear-$month';
                        final monthShows = byMonth[key] ?? [];
                        rowChildren.add(
                          SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: _MonthCard(
                              year: _selectedYear,
                              month: month,
                              shows: monthShows,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MonthDetailScreen(
                                    year: _selectedYear,
                                    month: month,
                                    shows: monthShows,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        rowChildren.add(SizedBox(width: cardWidth, height: cardHeight));
                      }
                    }
                    if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
                    rows.add(Row(children: rowChildren));
                  }

                  return Column(children: rows);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickYear(BuildContext context) async {
    final now = DateTime.now();
    final firstYear = now.year - 5;
    final lastYear = now.year + 5;

    await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Selecionar ano',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lastYear - firstYear + 1,
            itemBuilder: (_, i) {
              final year = firstYear + i;
              final isSelected = year == _selectedYear;
              return ListTile(
                title: Text(
                  '$year',
                  style: TextStyle(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 18)
                    : null,
                onTap: () {
                  setState(() => _selectedYear = year);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Year selector widget
// ─────────────────────────────────────────

class _YearSelector extends StatelessWidget {
  final int selectedYear;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTap;

  const _YearSelector({
    required this.selectedYear,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ArrowBtn(icon: Icons.chevron_left, onTap: onPrev),
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '$selectedYear',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          _ArrowBtn(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppTheme.textSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Year summary card
// ─────────────────────────────────────────

class _YearSummaryCard extends StatelessWidget {
  final int selectedYear;
  final double totalYear;
  final double earnedYear;
  final double cancelledYear;
  final int showCount;
  final DateTime now;
  final bool desktop;

  const _YearSummaryCard({
    required this.selectedYear,
    required this.totalYear,
    required this.earnedYear,
    required this.cancelledYear,
    required this.showCount,
    required this.now,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final pending = totalYear - earnedYear;

    return Container(
      padding: EdgeInsets.all(desktop ? 20 : 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGlow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                'Resumo $selectedYear',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '$showCount show${showCount != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Total $selectedYear',
                  value: AppFormatters.currency(totalYear),
                  color: AppTheme.primary,
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  label: selectedYear <= now.year ? 'Recebido' : 'Previsto',
                  value: AppFormatters.currency(selectedYear < now.year ? totalYear : earnedYear),
                  color: AppTheme.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  label: 'Cancelado',
                  value: AppFormatters.currency(cancelledYear),
                  color: AppTheme.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
              if (desktop) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _StatBox(
                    label: 'A receber',
                    value: AppFormatters.currency(pending),
                    color: AppTheme.secondary,
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ],
          ),
          if (totalYear > 0) ...[
            const SizedBox(height: 14),
            Text(
              '${AppFormatters.currency(pending)} restante',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Upcoming shows card
// ─────────────────────────────────────────

class _UpcomingShowsCard extends StatefulWidget {
  final List<ShowModel> nextShows;
  final DateTime today;
  final bool desktop;
  final double hPad;

  const _UpcomingShowsCard({
    required this.nextShows,
    required this.today,
    required this.desktop,
    required this.hPad,
  });

  @override
  State<_UpcomingShowsCard> createState() => _UpcomingShowsCardState();
}

class _UpcomingShowsCardState extends State<_UpcomingShowsCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.hPad, 0, widget.hPad, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        padding: EdgeInsets.all(widget.desktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGlow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.upcoming_rounded, color: AppTheme.secondary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Próximas datas',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.nextShows.length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.secondary),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.textMuted, size: 20),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  const SizedBox(height: 14),
                  ...widget.nextShows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final show = entry.value;
                    final showDay = DateTime(show.showDate.year, show.showDate.month, show.showDate.day);
                    final isToday = showDay == widget.today;
                    final daysLeft = showDay.difference(widget.today).inDays;

                    return Column(
                      children: [
                        if (i > 0) const Divider(color: AppTheme.border, height: 16, thickness: 1),
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isToday
                                      ? AppTheme.primary.withValues(alpha: 0.5)
                                      : AppTheme.border,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${show.showDate.day}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isToday ? AppTheme.primary : AppTheme.textPrimary,
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    AppConstants.monthNames[show.showDate.month - 1].substring(0, 3).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: isToday ? AppTheme.primary : AppTheme.textMuted,
                                      letterSpacing: 0.4,
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
                                    show.local,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isToday ? 'Hoje' : daysLeft == 1 ? 'Amanhã' : 'Em $daysLeft dias',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isToday ? AppTheme.primary : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppFormatters.currency(show.value),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Month card
// ─────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  final int year;
  final int month;
  final List<ShowModel> shows;
  final VoidCallback onTap;

  const _MonthCard({
    required this.year,
    required this.month,
    required this.shows,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;
    final isPast = DateTime(year, month + 1, 0).isBefore(DateTime(now.year, now.month, now.day));

    final activeShows = shows.where((s) => !s.cancelled).toList();
    final showDays = activeShows.map((s) => s.showDate.day).toList()..sort();
    final double totalMonth = activeShows.fold(0, (sum, s) => sum + s.value);
    final today = DateTime(now.year, now.month, now.day);
    final hasCancelled = shows.any((s) => s.cancelled);

    final bool hasShows = activeShows.isNotEmpty;
    final desktop = _isDesktop(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCurrentMonth ? AppTheme.primary.withValues(alpha: 0.6) : AppTheme.border,
            width: isCurrentMonth ? 1.5 : 1,
          ),
          boxShadow: isCurrentMonth
              ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.08), blurRadius: 12, spreadRadius: 0)]
              : null,
        ),
        padding: EdgeInsets.all(desktop ? 15 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month name + badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    AppConstants.monthNames[month - 1],
                    style: TextStyle(
                      fontSize: desktop ? 14 : 13,
                      fontWeight: FontWeight.w700,
                      color: isCurrentMonth ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrentMonth)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGlow,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'HOJE',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.primary, letterSpacing: 0.5),
                    ),
                  ),
                if (isPast && !isCurrentMonth && hasShows)
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 14),
                if (hasCancelled) ...[
                  const SizedBox(width: 2),
                  const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 13),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Show day bubbles
            if (hasShows) ...[
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: showDays.map((day) {
                  final isDone = DateTime(year, month, day).isBefore(today);
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone
                            ? AppTheme.success.withValues(alpha: 0.3)
                            : AppTheme.secondary.withValues(alpha: 0.25),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isDone ? AppTheme.success : AppTheme.secondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Text(
                    isPast ? '—' : 'Nenhuma data',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ),
            ],

            const Spacer(),

            if (hasShows) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${activeShows.length} data${activeShows.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    AppFormatters.currency(totalMonth),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  StatBox
// ─────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Container(
      padding: EdgeInsets.all(desktop ? 14 : 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: desktop ? 18 : 16, color: color.withValues(alpha: 0.9)),
          SizedBox(height: desktop ? 7 : 5),
          Text(
            label,
            style: TextStyle(fontSize: desktop ? 10 : 9, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: desktop ? 15 : 13, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MonthDetailScreen
// ─────────────────────────────────────────

class MonthDetailScreen extends ConsumerStatefulWidget {
  final int year;
  final int month;
  final List<ShowModel> shows;

  const MonthDetailScreen({
    super.key,
    required this.year,
    required this.month,
    required this.shows,
  });

  @override
  ConsumerState<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends ConsumerState<MonthDetailScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime(widget.year, widget.month);
  }

  List<ShowModel> get _allShows {
    final allShowsAsync = ref.watch(showsProvider).valueOrNull ?? widget.shows;
    return allShowsAsync
        .where((s) => s.showDate.year == _focusedDay.year && s.showDate.month == _focusedDay.month)
        .toList();
  }

  List<ShowModel> get _allShowsUnfiltered {
    return ref.watch(showsProvider).valueOrNull ?? widget.shows;
  }

  List<ShowModel> _showsForDay(DateTime day) {
    return _allShows.where((s) => isSameDay(s.showDate, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shows = _allShows;
    final desktop = _isDesktop(context);
    final isLandMobile = _isLandscapeMobile(context);

    final activeShows = shows.where((s) => !s.cancelled).toList();
    final cancelledShows = shows.where((s) => s.cancelled).toList();

    final double totalMonth = activeShows.fold(0, (sum, s) => sum + s.value);
    final double earnedMonth = activeShows
        .where((s) => DateTime(s.showDate.year, s.showDate.month, s.showDate.day).isBefore(today))
        .fold(0, (sum, s) => sum + s.value);
    final double pendingMonth = totalMonth - earnedMonth;
    final double cancelledMonth = cancelledShows.fold(0, (sum, s) => sum + s.value);

    final monthName = AppConstants.monthNames[_focusedDay.month - 1];
    final yearLabel = _focusedDay.year;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$monthName $yearLabel',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            if (activeShows.isNotEmpty)
              Text(
                '${activeShows.length} data${activeShows.length > 1 ? 's' : ''} · ${AppFormatters.currency(totalMonth)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        bottom: null,
      ),
      body: SafeArea(
        child: (desktop || isLandMobile)
            ? _buildDesktopLayout(context, shows, today, totalMonth, earnedMonth, pendingMonth, cancelledMonth)
            : _buildMobileLayout(context, shows, today, totalMonth, earnedMonth, pendingMonth, cancelledMonth),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<ShowModel> shows,
    DateTime today,
    double totalMonth,
    double earnedMonth,
    double pendingMonth,
    double cancelledMonth,
  ) {
    final isLandMobile = _isLandscapeMobile(context);
    final mq = MediaQuery.of(context);
    final systemLeft = mq.padding.left;
    final systemRight = mq.padding.right;
    final basePad = isLandMobile ? 12.0 : 32.0;
    final hPadLeft = basePad + systemLeft;
    final hPadRight = basePad + systemRight;
    final leftColWidth = isLandMobile ? 280.0 : 420.0;

    return _centered(
      Padding(
        padding: EdgeInsets.fromLTRB(hPadLeft, 8, hPadRight, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftColWidth,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (!isLandMobile) ...[
                      _buildStatsRow(totalMonth, earnedMonth, pendingMonth, cancelledMonth, true),
                      const SizedBox(height: 16),
                    ],
                    _buildCalendar(today),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLandMobile)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildStatsRow(totalMonth, earnedMonth, pendingMonth, cancelledMonth, false),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Datas do mês',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: shows.isEmpty
                        ? _buildEmptyMonth()
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: shows.length,
                            itemBuilder: (context, index) {
                              final show = shows[index];
                              final prevShow = index > 0 ? shows[index - 1] : null;
                              final showHeader = prevShow == null || !isSameDay(prevShow.showDate, show.showDate);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showHeader) _buildDayStrip(show.showDate, _showsForDay(show.showDate)),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ShowCard(
                                      show: show,
                                      onTap: () => _openEditSheet(context, show),
                                      onDelete: () => _confirmDelete(context, show),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      maxWidth: 1100,
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<ShowModel> shows,
    DateTime today,
    double totalMonth,
    double earnedMonth,
    double pendingMonth,
    double cancelledMonth,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _buildStatsRow(totalMonth, earnedMonth, pendingMonth, cancelledMonth, false),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: _buildCalendar(today)),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        if (shows.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyMonth())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final show = shows[index];
                  final prevShow = index > 0 ? shows[index - 1] : null;
                  final showHeader = prevShow == null || !isSameDay(prevShow.showDate, show.showDate);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) _buildDayStrip(show.showDate, _showsForDay(show.showDate)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ShowCard(
                          show: show,
                          onTap: () => _openEditSheet(context, show),
                          onDelete: () => _confirmDelete(context, show),
                        ),
                      ),
                    ],
                  );
                },
                childCount: shows.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow(double totalMonth, double earnedMonth, double pendingMonth, double cancelledMonth, bool desktop) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Total do mês',
            value: AppFormatters.currency(totalMonth),
            color: AppTheme.primary,
            icon: Icons.attach_money_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            label: 'Recebido',
            value: AppFormatters.currency(earnedMonth),
            color: AppTheme.success,
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            label: 'A receber',
            value: AppFormatters.currency(pendingMonth),
            color: AppTheme.secondary,
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            label: 'Cancelado',
            value: AppFormatters.currency(cancelledMonth),
            color: AppTheme.error,
            icon: Icons.cancel_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(DateTime today) {
    final desktop = _isDesktop(context);
    final isLandMobile = _isLandscapeMobile(context);
    final rowH = isLandMobile ? 32.0 : 44.0;
    final dowH = isLandMobile ? 20.0 : 18.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: (desktop || isLandMobile) ? 0 : 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: TableCalendar(
        firstDay: DateTime(2000, 1, 1),
        lastDay: DateTime(2100, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => _selectedDay != null && isSameDay(day, _selectedDay!),
        locale: 'pt_BR',
        startingDayOfWeek: StartingDayOfWeek.sunday,
        availableCalendarFormats: const {CalendarFormat.month: 'Mês'},
        calendarFormat: CalendarFormat.month,
        pageJumpingEnabled: true,
        rowHeight: rowH,
        daysOfWeekHeight: dowH,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textSecondary, size: 20),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
          headerPadding: EdgeInsets.symmetric(vertical: 12),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: true,
          outsideTextStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          cellMargin: EdgeInsets.all(4),
          defaultTextStyle: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          weekendTextStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          selectedDecoration: BoxDecoration(color: Colors.transparent),
          todayDecoration: BoxDecoration(color: Colors.transparent),
          selectedTextStyle: TextStyle(color: AppTheme.background, fontWeight: FontWeight.w700, fontSize: 13),
          todayTextStyle: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
            _selectedDay = null;
          });
        },
        onDaySelected: (selected, focused) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
          _openAddSheet(context, selected);
        },
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final dayShows = _allShows.where((s) => isSameDay(s.showDate, day)).toList();
            final hasActive = dayShows.any((s) => !s.cancelled);
            final hasCancelled = dayShows.any((s) => s.cancelled);
            if (!hasActive && !hasCancelled) return null;
            final isDone = !day.isAfter(today);
            final color = hasActive
                ? (isDone ? AppTheme.success : AppTheme.secondary)
                : AppTheme.error;
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxHeight - 8;
                return Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            final isToday = isSameDay(day, today);
            final dayShows = _allShowsUnfiltered.where((s) => isSameDay(s.showDate, day)).toList();
            final hasActive = dayShows.any((s) => !s.cancelled);
            final hasCancelled = dayShows.any((s) => s.cancelled);
            final isDone = !day.isAfter(today);
            final color = hasActive
                ? (isDone ? AppTheme.success : AppTheme.secondary)
                : AppTheme.error;
            if (!isToday && !hasActive && !hasCancelled) return null;
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxHeight - 8;
                final radius = BorderRadius.circular(8);
                if (isToday) {
                  return Center(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: (hasActive || hasCancelled) ? color.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: radius,
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: (hasActive || hasCancelled) ? color : AppTheme.primary,
                        ),
                      ),
                    ),
                  );
                }
                return Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: radius,
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.5)),
                    ),
                  ),
                );
              },
            );
          },
          todayBuilder: (context, day, focusedDay) {
            final dayShows = _allShows.where((s) => isSameDay(s.showDate, day)).toList();
            final hasActive = dayShows.any((s) => !s.cancelled);
            final hasCancelled = dayShows.any((s) => s.cancelled);
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxHeight - 8;
                final color = hasActive ? AppTheme.primary : (hasCancelled ? AppTheme.error : AppTheme.primary);
                return Center(
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: (hasActive || hasCancelled) ? color.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.7), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: (hasActive || hasCancelled) ? color : AppTheme.primary,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayStrip(DateTime date, List<ShowModel> dayShows) {
    final activeShows = dayShows.where((s) => !s.cancelled).toList();
    final totalValue = activeShows.fold<double>(0, (sum, s) => sum + s.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppFormatters.relativeDate(date),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              Text(
                AppFormatters.dateLong(date),
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (activeShows.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${activeShows.length} data${activeShows.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                Text(
                  AppFormatters.currency(totalValue),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonth() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.event_busy_outlined, color: AppTheme.textMuted, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhum show neste mês',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toque em um dia do calendário para adicionar',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context, DateTime date) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Adicionar Data',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return _ShowFormDialog(child: ShowFormSheet(date: date, ref: ref));
      },
    );
  }

  void _openEditSheet(BuildContext context, ShowModel show) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Editar data',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return _ShowFormDialog(child: ShowFormSheet(date: show.showDate, show: show, ref: ref));
      },
    );
  }

  void _confirmDelete(BuildContext context, ShowModel show) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
            SizedBox(width: 8),
            Text('Excluir data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Excluir a data em "${show.local}"?\n\nEssa ação não pode ser desfeita.',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(showsProvider.notifier).deleteShow(show.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                        SizedBox(width: 8),
                        Text('Data excluída'),
                      ],
                    ),
                    backgroundColor: AppTheme.cardElevated,
                  ),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  _ShowFormDialog
// ─────────────────────────────────────────

class _ShowFormDialog extends StatelessWidget {
  final Widget child;
  const _ShowFormDialog({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;
    final topInset = mq.padding.top;
    final bottomInset = mq.padding.bottom;
    final availableHeight = mq.size.height - keyboardHeight - topInset - bottomInset;
    final maxHeight = availableHeight * 0.96;
    final leftInset = mq.padding.left;
    final rightInset = mq.padding.right;

    return Padding(
      padding: EdgeInsets.only(left: leftInset, right: rightInset, bottom: keyboardHeight),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ShowFormSheet
// ─────────────────────────────────────────

class ShowFormSheet extends StatefulWidget {
  final DateTime date;
  final ShowModel? show;
  final WidgetRef ref;

  const ShowFormSheet({super.key, required this.date, this.show, required this.ref});

  @override
  State<ShowFormSheet> createState() => _ShowFormSheetState();
}

class _ShowFormSheetState extends State<ShowFormSheet> {
  final _localController = TextEditingController();
  final _valueController = TextEditingController();
  final _localFocus = FocusNode();
  bool _isLoading = false;
  bool get _isEditing => widget.show != null;
  bool get _isCancelled => widget.show?.cancelled ?? false;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _localController.text = widget.show!.local;
      _valueController.text = widget.show!.value.toStringAsFixed(2);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _localFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _localController.dispose();
    _valueController.dispose();
    _localFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final local = _localController.text.trim();
    final valueText = _valueController.text.replaceAll(',', '.');
    final value = double.tryParse(valueText) ?? 0.0;

    if (local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o local')));
      return;
    }
    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor válido')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isEditing) {
        final updated = widget.show!.copyWith(local: local, value: value);
        await widget.ref.read(showsProvider.notifier).updateShow(updated);
      } else {
        final show = ShowModel(
          id: '',
          userId: '',
          local: local,
          showDate: widget.date,
          value: value,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await widget.ref.read(showsProvider.notifier).addShow(show);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppTheme.error, size: 20),
            SizedBox(width: 8),
            Text('Cancelar data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Marcar a data em "${widget.show!.local}" como cancelada?\n\nO valor do cachê será adicionado em "cancelado".',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // fecha o form sheet
              setState(() => _isLoading = true);
              try {
                await widget.ref.read(showsProvider.notifier).cancelShow(widget.show!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: AppTheme.error, size: 16),
                          SizedBox(width: 8),
                          Text('Data cancelada'),
                        ],
                      ),
                      backgroundColor: AppTheme.cardElevated,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Cancelar data', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmUncancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.undo_rounded, color: AppTheme.success, size: 20),
            SizedBox(width: 8),
            Text('Descancelar data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Reativar a data em "${widget.show!.local}"?\n\nEla voltará a aparecer como data ativa.',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              try {
                await widget.ref.read(showsProvider.notifier).uncancelShow(widget.show!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                          SizedBox(width: 8),
                          Text('Data reativada'),
                        ],
                      ),
                      backgroundColor: AppTheme.cardElevated,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Descancelar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFromSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
            SizedBox(width: 8),
            Text('Excluir data', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Excluir definitivamente a data em "${widget.show!.local}"?\n\nEssa ação não pode ser desfeita.',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              try {
                await widget.ref.read(showsProvider.notifier).deleteShow(widget.show!.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                          SizedBox(width: 8),
                          Text('Data excluída'),
                        ],
                      ),
                      backgroundColor: AppTheme.cardElevated,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
                  );
                }
              }
            },
            child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _isCancelled ? AppTheme.error.withValues(alpha: 0.12) : AppTheme.primaryGlow,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _isCancelled
                              ? AppTheme.error.withValues(alpha: 0.3)
                              : AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        _isCancelled ? Icons.cancel_outlined : Icons.mic_rounded,
                        color: _isCancelled ? AppTheme.error : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCancelled ? 'Data cancelada' : (_isEditing ? 'Editar data' : 'Nova data'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Text(
                          AppFormatters.dateLong(widget.date),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),

                // Cancelled banner
                if (_isCancelled) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppTheme.error, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta data foi cancelada.',
                            style: TextStyle(fontSize: 12, color: AppTheme.error, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Uncancel button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _confirmUncancel(context),
                      icon: const Icon(Icons.undo_rounded, size: 18, color: AppTheme.success),
                      label: const Text(
                        'Descancelar esta data',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.success.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: AppTheme.success.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Delete cancelled show button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _confirmDeleteFromSheet(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
                      label: const Text(
                        'Excluir esta data',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: AppTheme.error.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                const Text(
                  'LOCAL',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _localController,
                  focusNode: _localFocus,
                  enabled: !_isCancelled,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Nome do local',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.textMuted, size: 20),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CACHÊ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _valueController,
                  enabled: !_isCancelled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0,00',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 24, fontWeight: FontWeight.w800),
                    prefixText: 'R\$ ',
                    prefixStyle: const TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.w700),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 22),

                // Save button (hidden if cancelled)
                if (!_isCancelled) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.background),
                            )
                          : Text(
                              _isEditing ? 'Salvar alterações' : 'Salvar',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],

                // Cancel show button (only when editing non-cancelled)
                if (_isEditing && !_isCancelled) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _confirmCancel(context),
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
                      label: const Text(
                        'Cancelar esta data',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: AppTheme.error.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}