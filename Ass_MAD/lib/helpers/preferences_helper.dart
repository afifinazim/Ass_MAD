import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static final PreferencesHelper instance = PreferencesHelper._init();
  PreferencesHelper._init();

  // ─── Keys ─────────────────────────────────────────────────
  static const _keyName = 'profile_name';
  static const _keyStudentId = 'profile_student_id';
  static const _keyClass = 'profile_class';
  static const _keyProgram = 'profile_program';
  static const _keyEmail = 'profile_email';
  static const _keyPhone = 'profile_phone';
  static const _keyImagePath = 'profile_image_path';
  static const _keyMonthlyGoal = 'monthly_goal';
  static const _keyDarkMode = 'dark_mode';
  static const _keyNotifications = 'notifications_enabled';
  static const _keyWeeklyReminder = 'weekly_reminder';
  static const _keyActivityReminder = 'activity_reminder';
  static const _keyOnboarded = 'onboarded';
  static const _keyPedometerGoal = 'pedometer_goal';

  // ─── PROFILE ──────────────────────────────────────────────
  Future<void> saveProfile({
    required String name,
    required String studentId,
    required String studentClass,
    required String program,
    required String email,
    required String phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyStudentId, studentId);
    await prefs.setString(_keyClass, studentClass);
    await prefs.setString(_keyProgram, program);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPhone, phone);
  }

  Future<Map<String, String>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyName) ?? '',
      'studentId': prefs.getString(_keyStudentId) ?? '',
      'class': prefs.getString(_keyClass) ?? 'DCS 5A',
      'program': prefs.getString(_keyProgram) ?? '',
      'email': prefs.getString(_keyEmail) ?? '',
      'phone': prefs.getString(_keyPhone) ?? '',
      'imagePath': prefs.getString(_keyImagePath) ?? '',
    };
  }

  Future<void> saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyImagePath, path);
  }

  Future<String> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyImagePath) ?? '';
  }

  // ─── MONTHLY GOAL ─────────────────────────────────────────
  Future<void> setMonthlyGoal(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMonthlyGoal, hours);
  }

  Future<int> getMonthlyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMonthlyGoal) ?? 50;
  }

  // ─── PEDOMETER GOAL ───────────────────────────────────────
  Future<void> setPedometerGoal(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPedometerGoal, steps);
  }

  Future<int> getPedometerGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPedometerGoal) ?? 10000;
  }

  // ─── DARK MODE ────────────────────────────────────────────
  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  // ─── NOTIFICATIONS ────────────────────────────────────────
  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifications) ?? true;
  }

  Future<void> setWeeklyReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeeklyReminder, value);
  }

  Future<bool> getWeeklyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWeeklyReminder) ?? true;
  }

  Future<void> setActivityReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyActivityReminder, value);
  }

  Future<bool> getActivityReminder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyActivityReminder) ?? true;
  }

  // ─── ONBOARDING ───────────────────────────────────────────
  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, value);
  }

  Future<bool> getOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarded) ?? false;
  }

  // ─── CLEAR ALL ────────────────────────────────────────────
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
