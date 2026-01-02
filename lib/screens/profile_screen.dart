import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  static const routeName = '/profile';

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
              ListTile(
                leading: CircleAvatar(child: Text(user.fullName.characters.first)),
                title: Text(user.fullName),
                subtitle: Text(user.email),
                trailing: Chip(label: Text(user.userType.name.toUpperCase())),
              ),
              ListTile(
                title: const Text('Department/Major'),
                subtitle: Text(user.department ?? 'Not set'),
              ),
              ListTile(
                title: const Text('ID'),
                subtitle: Text(user.studentId ?? user.facultyId ?? 'Not set'),
              ),
              SwitchListTile(
                value: user.isGoogleCalendarConnected,
                onChanged: (_) {},
                title: const Text('Google Calendar Connected'),
              ),
            ],
            const Divider(),
            ListTile(
              title: const Text('App Version'),
              subtitle: const Text('0.1.0'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: AppColors.error),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
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
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, LoginScreen.routeName, (_) => false);
                }
              },
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
