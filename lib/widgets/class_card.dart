import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class ClassCard extends StatelessWidget {
  const ClassCard({super.key, required this.model, this.onTap, this.onEdit, this.onDelete});

  final ClassModel model;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String _formatTime(TimeOfDay t) => localizations.formatTimeOfDay(t, alwaysUse24HourFormat: false);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: model.color, child: const Icon(Icons.event, color: Colors.white)),
        title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${_formatTime(model.startTime)} - ${_formatTime(model.endTime)} | ${model.location}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (model.syncWithGoogle)
              Icon(Icons.cloud_done, color: AppColors.accent, size: 20)
            else
              const Icon(Icons.cloud_off, size: 20, color: AppColors.textSecondary),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
