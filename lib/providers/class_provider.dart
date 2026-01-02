import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/local_db_service.dart';

class ClassProvider extends ChangeNotifier {
  ClassProvider(this._dbService);

  final LocalDbService _dbService;
  List<ClassModel> _classes = [];
  bool _loading = false;

  List<ClassModel> get classes => _classes;
  bool get isLoading => _loading;

  Future<void> loadForUser(String userId, {required bool isStudent}) async {
    _loading = true;
    notifyListeners();
    _classes = await _dbService.loadClasses(userId);
    if (_classes.isEmpty) {
      _classes = _dbService.sampleClasses(userId, isStudent);
      for (final c in _classes) {
        await _dbService.insertClass(c);
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> addOrUpdate(ClassModel model) async {
    final exists = _classes.indexWhere((c) => c.id == model.id);
    if (exists >= 0) {
      _classes[exists] = model;
      await _dbService.updateClass(model);
    } else {
      _classes.add(model);
      await _dbService.insertClass(model);
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _classes.removeWhere((c) => c.id == id);
    await _dbService.deleteClass(id);
    notifyListeners();
  }
}
