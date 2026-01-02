import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  static const routeName = '/select-role';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.calendar_month, size: 64, color: AppColors.primary),
              const SizedBox(height: 12),
              Text('Smart Scheduler', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Choose your role to continue', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                  children: [
                    _RoleCard(
                      title: 'Student',
                      icon: Icons.school,
                      color: AppColors.primary,
                      onTap: () => Navigator.pushNamed(
                        context,
                        LoginScreen.routeName,
                        arguments: const LoginArgs(UserType.student),
                      ),
                    ),
                    _RoleCard(
                      title: 'Faculty',
                      icon: Icons.work_outline,
                      color: AppColors.secondary,
                      onTap: () => Navigator.pushNamed(
                        context,
                        LoginScreen.routeName,
                        arguments: const LoginArgs(UserType.faculty),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.title, required this.icon, required this.color, required this.onTap});

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                radius: 32,
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Dedicated ${title.toLowerCase()} portal', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
