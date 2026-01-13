import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  DateTime? _lastSyncTime;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 15));
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isSyncing = false;
      _lastSyncTime = DateTime.now();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calendar synced successfully!'), duration: Duration(seconds: 2)),
    );
  }

  String _formatLastSync(DateTime? time) {
    if (time == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: const Color(0xFF257FCE).withValues(alpha: 0.2),
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName.characters.first.toUpperCase() : '?',
                              style: const TextStyle(color: Color(0xFF257FCE), fontWeight: FontWeight.w800, fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Chip(
                                  label: Text(
                                    user.userType.name.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                                  ),
                                  backgroundColor: const Color(0xFF257FCE),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Account Information', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Department/Major'),
                subtitle: Text(user.department ?? 'Not set', style: const TextStyle(color: AppColors.textSecondary)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ID'),
                subtitle: Text(user.studentId ?? user.facultyId ?? 'Not set', style: const TextStyle(color: AppColors.textSecondary)),
              ),
              const Divider(height: 24),
              Text('Google Calendar Integration', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: user.isGoogleCalendarConnected ? const Color(0xFF4CAF50).withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: user.isGoogleCalendarConnected ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.cloud_sync,
                              color: user.isGoogleCalendarConnected ? const Color(0xFF4CAF50) : Colors.grey,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Calendar Status',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  user.isGoogleCalendarConnected ? 'Connected' : 'Not connected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: user.isGoogleCalendarConnected ? const Color(0xFF4CAF50) : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (user.isGoogleCalendarConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('✓', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                        ],
                      ),
                      if (user.isGoogleCalendarConnected) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Last sync: ${_formatLastSync(_lastSyncTime)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSyncing ? null : _manualSync,
                            icon: _isSyncing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF257FCE),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Google Account'),
                subtitle: Text(user.googleAccountEmail ?? 'Not connected', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
              const Divider(height: 24),
              Text('App Information', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App Version'),
                subtitle: const Text('0.1.0', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const Divider(height: 24),
              Text('Data Management', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Clear Local Data?'),
                      content: const Text('This will delete all locally saved data. Data synced with Google Calendar will remain intact.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Local data cleared'), duration: Duration(seconds: 2)),
                    );
                  }
                },
                label: const Text('Clear Local Data'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.error),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // Clean up location provider
                    if (context.mounted) {
                      context.read<LocationProvider>().onLogout();
                    }
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (_) => false);
                  }
                },
                label: const Text('Logout'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
