import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavCard extends StatelessWidget {
  const NavCard({super.key, required this.title, required this.icon, this.subtitle, this.meta, this.onTap, this.accent});

  final String title;
  final String? subtitle;
  final String? meta;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  if (meta != null)
                    Text(meta!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
