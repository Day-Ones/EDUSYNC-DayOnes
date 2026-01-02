import 'package:flutter/material.dart';

class ConflictResolutionScreen extends StatelessWidget {
  const ConflictResolutionScreen({super.key});
  static const routeName = '/conflicts';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Conflicts')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No conflicts right now. When sync detects a conflict, options will appear here.'),
        ),
      ),
    );
  }
}
