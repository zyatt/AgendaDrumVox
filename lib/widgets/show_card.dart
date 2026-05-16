// lib/widgets/show_card.dart

import 'package:flutter/material.dart';
import '../models/show_model.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

class ShowCard extends StatelessWidget {
  final ShowModel show;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ShowCard({
    super.key,
    required this.show,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final showDay = DateTime(show.showDate.year, show.showDate.month, show.showDate.day);
    final isPast = showDay.isBefore(today);
    final isToday = showDay == today;
    final isCancelled = show.cancelled;

    final accentColor = isCancelled
        ? AppTheme.error
        : isToday
            ? AppTheme.primary
            : isPast
                ? AppTheme.success
                : AppTheme.secondary;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isCancelled ? 0.65 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCancelled
                  ? AppTheme.error.withValues(alpha: 0.35)
                  : isToday
                      ? AppTheme.primary.withValues(alpha: 0.5)
                      : AppTheme.border,
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Left accent bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      // Icon bubble
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                        ),
                        child: Icon(
                          isCancelled
                              ? Icons.cancel_outlined
                              : isToday
                                  ? Icons.mic_rounded
                                  : isPast
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.location_on_rounded,
                          color: accentColor,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              show.local,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isCancelled ? AppTheme.textSecondary : AppTheme.textPrimary,
                                height: 1.2,
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                decorationColor: AppTheme.error,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isCancelled
                                  ? 'Cancelado'
                                  : isToday
                                      ? 'Hoje'
                                      : isPast
                                          ? 'Realizado'
                                          : AppFormatters.relativeDate(show.showDate),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Value
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.currency(show.value),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isCancelled ? AppTheme.error : AppTheme.primary,
                              letterSpacing: -0.2,
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                              decorationColor: AppTheme.error,
                            ),
                          ),
                          if (onDelete != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: onDelete,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(Icons.delete_outline_rounded,
                                    size: 15, color: AppTheme.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Cancelled ribbon badge
                if (isCancelled)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border(
                          left: BorderSide(color: AppTheme.error.withValues(alpha: 0.25)),
                          bottom: BorderSide(color: AppTheme.error.withValues(alpha: 0.25)),
                        ),
                      ),
                      child: const Text(
                        'CANCELADO',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.error,
                          letterSpacing: 0.6,
                        ),
                      ),
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