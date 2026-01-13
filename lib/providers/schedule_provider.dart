import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../services/local_db_service.dart';

class ScheduleProvider extends ChangeNotifier {
  ScheduleProvider(this._dbService);

  final LocalDbService _dbService;
  List<ScheduleModel> _schedules = [];
  bool _loading = false;
  DateTime _selectedDate = DateTime.now();

  List<ScheduleModel> get schedules => _schedules;
  bool get isLoading => _loading;
  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  List<ScheduleModel> getSchedulesForDate(DateTime date) {
    return _schedules.where((s) {
      if (s.isRecurring) {
        return s.recurringDays.contains(date.weekday);
      }
      return s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day;
    }).toList()
      ..sort((a, b) {
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });
  }

  List<ScheduleModel> getTodaySchedules() {
    return getSchedulesForDate(DateTime.now());
  }

  List<ScheduleModel> getUpcomingSchedules() {
    final currentTime = TimeOfDay.now();
    return getTodaySchedules().where((s) {
      final sMinutes = s.startTime.hour * 60 + s.startTime.minute;
      final nowMinutes = currentTime.hour * 60 + currentTime.minute;
      return sMinutes > nowMinutes;
    }).toList();
  }

  Future<void> loadForUser(String userId) async {
    _loading = true;
    notifyListeners();
    _schedules = await _dbService.loadSchedules(userId);
    _loading = false;
    notifyListeners();
  }

  Future<void> addSchedule(ScheduleModel schedule) async {
    _schedules.add(schedule);
    await _dbService.insertSchedule(schedule);
    notifyListeners();
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index >= 0) {
      _schedules[index] = schedule;
      await _dbService.updateSchedule(schedule);
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(String id) async {
    _schedules.removeWhere((s) => s.id == id);
    await _dbService.deleteSchedule(id);
    notifyListeners();
  }

  Future<void> toggleComplete(String id) async {
    final index = _schedules.indexWhere((s) => s.id == id);
    if (index >= 0) {
      final schedule = _schedules[index];
      final updated = schedule.copyWith(isCompleted: !schedule.isCompleted);
      _schedules[index] = updated;
      await _dbService.updateSchedule(updated);
      notifyListeners();
    }
  }
}
