import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/class.dart';
import '../providers/class_provider.dart';
import '../widgets/class_card.dart';

class WeeklyViewScreen extends StatefulWidget {
  const WeeklyViewScreen({super.key});
  static const routeName = '/weekly';

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  List<ClassModel> _classesForDay(List<ClassModel> classes, DateTime day) {
    final weekday = day.weekday; // 1=Mon
    return classes.where((c) => c.daysOfWeek.contains(weekday)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>().classes;

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly View')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Hook for manual sync later.
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                currentDay: DateTime.now(),
                calendarFormat: CalendarFormat.week,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: _classesForDay(classes, _selectedDay ?? DateTime.now())
                      .map((c) => ClassCard(model: c, onTap: () {}))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
