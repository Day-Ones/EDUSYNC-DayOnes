import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';
import '../providers/sync_manager_provider.dart';

/// Widget that displays connectivity status and pending sync information
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final syncManager = context.watch<SyncManagerProvider>();

    // Don't show banner if online and not syncing
    if (connectivity.isOnline && !syncManager.isSyncing) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: connectivity.isOnline ? Colors.blue.shade700 : Colors.red.shade700,
      child: Row(
        children: [
          Icon(
            connectivity.isOnline ? Icons.sync : Icons.wifi_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connectivity.isOnline
                  ? (syncManager.isSyncing
                      ? 'Syncing data...'
                      : syncManager.lastSyncStatus ?? 'Online')
                  : 'Offline - Some features unavailable',
              style: GoogleFonts.albertSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (connectivity.isOnline && !syncManager.isSyncing)
            TextButton(
              onPressed: () => syncManager.manualSync(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Sync Now',
                style: GoogleFonts.albertSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget to show pending sync count badge
class PendingSyncBadge extends StatelessWidget {
  final int count;

  const PendingSyncBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sync_problem, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '$count pending',
            style: GoogleFonts.albertSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
