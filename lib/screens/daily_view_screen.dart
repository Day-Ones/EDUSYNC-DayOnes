import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../widgets/class_card.dart';

class DailyViewScreen extends StatelessWidget {
  const DailyViewScreen({super.key});
  static const routeName = '/daily';

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>().classes;
    final today = DateTime.now().weekday;
    final todaysClasses = classes.where((c) => c.daysOfWeek.contains(today)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Today's Classes")),
      body: SafeArea(
        child: todaysClasses.isEmpty
            ? const Center(child: Text('No classes today. Enjoy your day!'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: todaysClasses.length,
                itemBuilder: (_, i) => ClassCard(model: todaysClasses[i]),
              ),
      ),
    );
  }
}
