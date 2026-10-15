import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:my_helpers_flutter/features/aloc.dart';

/// Footer layout:
/// - Center: `First``Prev`  (chips area, as many as fits)  `Next``Last`
///   Icon buttons stay in fixed positions; only the chip strip flexes.
/// - Right: rows-per-page selector (fixed position)
class TablePagerFooter extends StatelessWidget {
  const TablePagerFooter({
    required this.total,
    required this.rowsPerPage,
    required this.currentPage, // 0-based
    required this.availableRowsPerPage,
    required this.onRowsPerPageChanged,
    required this.onPageChanged,
    super.key,
    this.chipWidth = 40,
    this.chipGap = 6,
  });

  final int total;
  final int rowsPerPage;
  final int currentPage;
  final List<int> availableRowsPerPage;

  final ValueChanged<int> onRowsPerPageChanged;
  final ValueChanged<int> onPageChanged;

  final double chipWidth;
  final double chipGap;

  static double _quantizeStripWidth(
    double w, {
    required double chipWidth,
    required double gap,
    double hysteresisFraction = 0.5, // "more than half chip"
  }) {
    final step = chipWidth + gap;
    if (w <= 0) return 0;

    // Move boundary by half-step so it only flips when crossing mid-point.
    final bias = step * hysteresisFraction;
    final k = ((w + bias) / step).floor();
    return math.max(0, k - 1) * step;
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = (total <= 0) ? 1 : ((total + rowsPerPage - 1) ~/ rowsPerPage);
    final lastPage = pageCount - 1;

    final canFirst = currentPage > 0;
    final canPrev = currentPage > 0;
    final canNext = currentPage < lastPage;
    final canLast = currentPage < lastPage;

    // Right side width is stable but can vary a bit by locale; we measure it.
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Center group: fixed icon clusters + flexible chips area
            const iconW = 40.0; // IconButton width-ish
            const iconGap = 2.0;

            const leftIconsW = iconW * 2 + iconGap; // first + prev
            const rightIconsW = iconW * 2 + iconGap; // next + last

            // Reserve some space for the right dropdown block.
            // (Keep it hard-right; chips should not push it.)
            const rightBlockMinW = 160.0;

            // Width available for the entire centered group (icons + chips).
            final centerGroupMaxW = math.max<double>(
              0,
              constraints.maxWidth - rightBlockMinW,
            );

            // Chips strip width inside the centered group.
            final chipsStripWRaw = math.max<double>(
              0,
              centerGroupMaxW - leftIconsW - rightIconsW,
            );

            // Quantize so it doesn't constantly jiggle around slot boundaries.
            final chipsStripW = _quantizeStripWidth(
              chipsStripWRaw,
              chipWidth: chipWidth,
              gap: chipGap,
            );

            // Now max slots is stable:
            final maxChipSlots = _maxChipSlots(
              chipsStripW,
              chipWidth: chipWidth,
              gap: chipGap,
            );

            final pages = _pagesToShowAdaptive(
              current: currentPage,
              last: lastPage,
              maxSlots: maxChipSlots,
            );

            return Row(
              children: [
                Stack(
                  children: [
                    // CENTERED GROUP (icons fixed; chips flex)
                    Align(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: centerGroupMaxW),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: leftIconsW,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: iconW,
                                    child: IconButton(
                                      tooltip: aloc('First page|Trang đầu|Первая'),
                                      onPressed: canFirst ? () => onPageChanged(0) : null,
                                      icon: const Icon(Icons.first_page),
                                    ),
                                  ),
                                  const SizedBox(width: iconGap),
                                  SizedBox(
                                    width: iconW,
                                    child: IconButton(
                                      tooltip: aloc('Previous|Trước|Назад'),
                                      onPressed: canPrev ? () => onPageChanged(currentPage - 1) : null,
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Flexible chips strip (as many as fits)
                            SizedBox(
                              width: chipsStripW,
                              child: Align(
                                child: SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final p in pages) ...[
                                        if (p == null)
                                          _EllipsisChip(width: chipWidth)
                                        else
                                          _PageChip(
                                            width: chipWidth,
                                            pageIndex: p,
                                            isCurrent: p == currentPage,
                                            onTap: () => onPageChanged(p),
                                          ),
                                        SizedBox(width: chipGap),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              width: rightIconsW,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: iconW,
                                    child: IconButton(
                                      tooltip: aloc('Next|Sau|Далее'),
                                      onPressed: canNext ? () => onPageChanged(currentPage + 1) : null,
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ),
                                  const SizedBox(width: iconGap),
                                  SizedBox(
                                    width: iconW,
                                    child: IconButton(
                                      tooltip: aloc('Last page|Trang cuối|Последняя'),
                                      onPressed: canLast ? () => onPageChanged(lastPage) : null,
                                      icon: const Icon(Icons.last_page),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // RIGHT BLOCK (hard-right position)
                    // Align(
                    //   alignment: Alignment.centerRight,
                    //   child: ConstrainedBox(
                    //     constraints: const BoxConstraints(minWidth: rightBlockMinW),
                    //     child: Row(
                    //       mainAxisSize: MainAxisSize.min,
                    //
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
                // children: [
                const Gap(8),
                Text(
                  aloc('Rows|Dòng|Строк'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: rowsPerPage,
                  items: [
                    for (final v
                        in (availableRowsPerPage.contains(rowsPerPage)
                            ? availableRowsPerPage
                            : [...availableRowsPerPage, rowsPerPage]))
                      DropdownMenuItem<int>(
                        value: v,
                        child: Text('$v'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null || v == rowsPerPage) return;
                    onRowsPerPageChanged(v);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static int _maxChipSlots(double stripWidth, {required double chipWidth, required double gap}) {
    if (stripWidth <= 0) return 0;
    final per = chipWidth + gap;
    // n * chipWidth + (n-1) * gap <= stripWidth  ->  n <= (stripWidth + gap) / (chipWidth + gap)
    return math.max(0, ((stripWidth + gap) / per).floor());
  }

  /// Returns a list like: [0, null, 4,5,6, null, 19] (null => "…")
  static List<int?> _pagesToShowAdaptive({
    required int current,
    required int last,
    required int maxSlots,
  }) {
    if (last < 0) return const <int?>[];
    if (maxSlots <= 0) return const <int?>[];

    // If all pages fit, show all
    final pageCount = last + 1;
    if (pageCount <= maxSlots) {
      return List<int?>.generate(pageCount, (i) => i);
    }

    // Very tight space: show only current (or current + last)
    if (maxSlots == 1) return <int?>[current];
    if (maxSlots == 2) {
      if (current == 0) return <int?>[0, last];
      if (current == last) return <int?>[0, last];
      return <int?>[current, last];
    }

    // General case: aim to show first + last, and a window around current.
    var start = math.max(1, current - ((maxSlots - 2) ~/ 2));
    var end = math.min(last - 1, start + (maxSlots - 3));

    // If we hit the end, shift start left
    start = math.max(1, end - (maxSlots - 3));

    List<int?> build(int s, int e) {
      final out = <int?>[0];

      if (s > 1) out.add(null);
      for (var i = s; i <= e; i++) {
        out.add(i);
      }
      if (e < last - 1) out.add(null);

      out.add(last);
      return out;
    }

    var out = build(start, end);

    // If ellipses made it exceed maxSlots, shrink the middle range until it fits.
    while (out.length > maxSlots && start <= end) {
      final leftDist = (current - start).abs();
      final rightDist = (end - current).abs();

      if (rightDist >= leftDist) {
        end -= 1;
      } else {
        start += 1;
      }
      out = build(start, end);
    }

    // Still too long? drop ellipses first (worst-case)
    if (out.length > maxSlots) {
      out = out.where((x) => x != null).toList();
      if (out.length > maxSlots) {
        out = out.take(maxSlots).toList();
      }
    }

    return out;
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.pageIndex,
    required this.isCurrent,
    required this.onTap,
    this.width = 40,
  });

  final int pageIndex; // 0-based
  final bool isCurrent;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: isCurrent ? null : onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            color: isCurrent ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
          ),
          child: Text(
            '${pageIndex + 1}',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _EllipsisChip extends StatelessWidget {
  const _EllipsisChip({this.width = 40});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: const Text('…'),
      ),
    );
  }
}
