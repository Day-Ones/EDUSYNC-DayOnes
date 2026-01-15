import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';
import '../providers/sync_manager_provider.dart';
import '../providers/attendance_provider.dart';

/// Widget that displays connectivity status and pending sync information
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    final syncManager = context.watch<SyncManagerProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final pendingCount = attendanceProvider.pendingSyncCount;

    // Don't show banner if online and not syncing and no pending items
    if (connectivity.isOnline && !syncManager.isSyncing && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: connectivity.isOnline ? Colors.blue.shade700 : Colors.grey.shade800,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              connectivity.isOnline 
                  ? (syncManager.isSyncing ? Icons.sync : Icons.cloud_done_rounded)
                  : Icons.wifi_off_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    connectivity.isOnline
                        ? (syncManager.isSyncing
                            ? 'Syncing data...'
                            : pendingCount > 0 
                                ? '$pendingCount item${pendingCount > 1 ? 's' : ''} pending sync'
                                : syncManager.lastSyncStatus ?? 'Online')
                        : 'You\'re offline',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!connectivity.isOnline)
                    Text(
                      'Connect to internet to sync with your instructors',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                ],
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
                  backgroundColor: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Sync Now',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
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
            style: GoogleFonts.inter(
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
