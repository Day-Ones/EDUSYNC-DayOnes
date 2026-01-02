import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../providers/sync_provider.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';

class CalendarSettingsScreen extends StatelessWidget {
  const CalendarSettingsScreen({super.key});
  static const routeName = '/calendar-settings';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();
    final classes = context.watch<ClassProvider>().classes;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Google Calendar Sync')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(user?.googleAccountEmail ?? 'Not connected'),
              subtitle: Text(user?.isGoogleCalendarConnected == true ? 'Connected' : 'Disconnected'),
              trailing: ElevatedButton(
                onPressed: () async {
                  final email = await sync.signIn();
                  if (email != null && user != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Signed in as $email')),
                    );
                  }
                },
                child: Text(user?.isGoogleCalendarConnected == true ? 'Sign Out' : 'Sign In'),
              ),
            ),
            const Divider(),
            SwitchListTile(
              value: true,
              onChanged: (_) {},
              title: const Text('Enable two-way sync'),
              subtitle: Text(sync.status ?? 'Ready'),
            ),
            ListTile(
              title: const Text('Manual Sync'),
              subtitle: Text(sync.lastSync != null ? 'Last sync: ${sync.lastSync}' : 'Not synced yet'),
              trailing: ElevatedButton(
                onPressed: sync.isSyncing || user == null
                    ? null
                    : () => sync.sync(user, classes),
                child: sync.isSyncing ? const CircularProgressIndicator(color: Colors.white) : const Text('Sync Now'),
              ),
            ),
            ListTile(
              title: const Text('Import from Google Calendar'),
              trailing: const Icon(Icons.download),
              onTap: () {},
            ),
            ListTile(
              title: const Text('Export to Google Calendar'),
              trailing: const Icon(Icons.upload),
              onTap: () {},
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Status colors', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Synced: green, Pending: orange, Error: red, Not synced: grey'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
