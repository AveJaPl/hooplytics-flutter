import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/session.dart';
import '../database/database_helper.dart';

class SessionProvider with ChangeNotifier {
  ShootingSession? _currentSession;

  ShootingSession? get currentSession => _currentSession;

  void startNewSession(String position, String range) {
    _currentSession = ShootingSession(
      id: const Uuid().v4(),
      position: position,
      range: range,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void addShot(bool isMake) {
    if (_currentSession != null) {
      _currentSession!.attempts++;
      if (isMake) {
        _currentSession!.makes++;
      }
      notifyListeners();
    }
  }

  void updateStatsManual(int makes, int attempts) {
    if (_currentSession != null) {
      _currentSession!.makes = makes;
      _currentSession!.attempts = attempts;
      notifyListeners();
    }
  }

  Future<void> endSession() async {
    if (_currentSession != null) {
      await DatabaseHelper().insertSession(_currentSession!);
      _currentSession = null;
      notifyListeners();
    }
  }
}
