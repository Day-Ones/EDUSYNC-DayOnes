import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, this.subtitle, this.icon, this.trend, this.trendColor, this.actionLabel, this.onAction});

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final String? trend;
  final Color? trendColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(value, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.0)),
                      const SizedBox(width: 8),
                      if (trend != null)
                        Text(trend!, style: TextStyle(color: trendColor ?? AppColors.accent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (actionLabel != null)
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(minimumSize: const Size(72, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
