import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../main.dart';
import '../helpers/preferences_helper.dart';
import '../helpers/notification_helper.dart';
import '../helpers/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _weeklyReminder = true;
  bool _activityReminder = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;
  int _monthlyGoal = 50;
  int _pedometerGoal = 10000;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notif = await PreferencesHelper.instance
        .getNotificationsEnabled();
    final weekly =
    await PreferencesHelper.instance.getWeeklyReminder();
    final activity = await PreferencesHelper.instance
        .getActivityReminder();
    final goal =
    await PreferencesHelper.instance.getMonthlyGoal();
    final pedGoal =
    await PreferencesHelper.instance.getPedometerGoal();

    setState(() {
      _notificationsEnabled = notif;
      _weeklyReminder = weekly;
      _activityReminder = activity;
      _monthlyGoal = goal;
      _pedometerGoal = pedGoal;
      _isLoading = false;
    });
  }

  Future<void> _vibrate() async {
    if (_vibrationEnabled) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 40);
      }
    }
  }

  Future<void> _setNotifications(bool v) async {
    await _vibrate();
    await PreferencesHelper.instance
        .setNotificationsEnabled(v);
    setState(() => _notificationsEnabled = v);
    if (!v) await NotificationHelper.instance.cancelAll();
  }

  Future<void> _setWeeklyReminder(bool v) async {
    await _vibrate();
    await PreferencesHelper.instance.setWeeklyReminder(v);
    setState(() => _weeklyReminder = v);
    if (v && _notificationsEnabled) {
      final activities =
      await DatabaseHelper.instance.getAllActivities();
      final hours =
      await DatabaseHelper.instance.getTotalHours();
      await NotificationHelper.instance
          .scheduleWeeklySummary(
        totalActivities: activities.length,
        totalHours: hours,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '📅 Weekly summary scheduled for Mondays at 8AM'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await NotificationHelper.instance
          .cancelWeeklySummary();
    }
  }

  Future<void> _setActivityReminder(bool v) async {
    await _vibrate();
    await PreferencesHelper.instance
        .setActivityReminder(v);
    setState(() => _activityReminder = v);
  }

  Future<void> _testNotification() async {
    await _vibrate();
    await NotificationHelper.instance.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 Test notification sent!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showGoalDialog() {
    final ctrl =
    TextEditingController(text: '$_monthlyGoal');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Hours per month',
            suffixText: 'hours',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0) {
                await PreferencesHelper.instance
                    .setMonthlyGoal(val);
                setState(() => _monthlyGoal = val);
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content:
                      Text('✅ Goal set to $val hours/month'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB),
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPedometerGoalDialog() {
    final ctrl =
    TextEditingController(text: '$_pedometerGoal');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Daily Step Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Steps per day',
            suffixText: 'steps',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0) {
                await PreferencesHelper.instance
                    .setPedometerGoal(val);
                setState(() => _pedometerGoal = val);
                if (mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A11CB),
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDataConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
            'This will permanently delete ALL your activities. This cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance
                  .deleteAllActivities();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                    Text('🗑️ All activity data cleared'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Appearance ──────────────────────────
          _sectionHeader('🎨 Appearance'),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                      isDark
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: const Color(0xFF6A11CB)),
                  title: const Text('Dark Mode'),
                  subtitle: Text(isDark
                      ? 'Dark theme is on'
                      : 'Light theme is on'),
                  value: isDark,
                  activeColor: const Color(0xFF6A11CB),
                  onChanged: (v) async {
                    await _vibrate();
                    themeProvider.toggleTheme(v);
                  },
                ),
                const Divider(height: 0),
                SwitchListTile(
                  secondary: const Icon(
                      Icons.vibration,
                      color: Colors.teal),
                  title: const Text('Vibration Feedback'),
                  subtitle: const Text(
                      'Haptic feedback on interactions'),
                  value: _vibrationEnabled,
                  activeColor: const Color(0xFF6A11CB),
                  onChanged: (v) {
                    setState(
                            () => _vibrationEnabled = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Goals ───────────────────────────────
          _sectionHeader('🎯 Goals'),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag,
                      color: Color(0xFF6A11CB)),
                  title:
                  const Text('Monthly Hour Goal'),
                  subtitle:
                  Text('Current: $_monthlyGoal hours'),
                  trailing:
                  const Icon(Icons.chevron_right),
                  onTap: _showGoalDialog,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(
                      Icons.directions_walk,
                      color: Colors.green),
                  title:
                  const Text('Daily Step Goal'),
                  subtitle: Text(
                      'Current: $_pedometerGoal steps'),
                  trailing:
                  const Icon(Icons.chevron_right),
                  onTap: _showPedometerGoalDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Notifications ───────────────────────
          _sectionHeader('🔔 Notifications'),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                      Icons.notifications,
                      color: Color(0xFF6A11CB)),
                  title: const Text(
                      'Push Notifications'),
                  subtitle: const Text(
                      'Enable all notifications'),
                  value: _notificationsEnabled,
                  activeColor: const Color(0xFF6A11CB),
                  onChanged: _setNotifications,
                ),
                const Divider(height: 0),
                SwitchListTile(
                  secondary: const Icon(
                      Icons.calendar_month,
                      color: Colors.blue),
                  title: const Text(
                      'Weekly Summary'),
                  subtitle: const Text(
                      'Every Monday at 8AM'),
                  value: _weeklyReminder &&
                      _notificationsEnabled,
                  activeColor: const Color(0xFF6A11CB),
                  onChanged: _notificationsEnabled
                      ? _setWeeklyReminder
                      : null,
                ),
                const Divider(height: 0),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm,
                      color: Colors.orange),
                  title:
                  const Text('Activity Reminders'),
                  subtitle: const Text(
                      'Reminder before activities'),
                  value: _activityReminder &&
                      _notificationsEnabled,
                  activeColor: const Color(0xFF6A11CB),
                  onChanged: _notificationsEnabled
                      ? _setActivityReminder
                      : null,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.send,
                      color: Colors.green),
                  title:
                  const Text('Test Notification'),
                  trailing: ElevatedButton(
                    onPressed: _notificationsEnabled
                        ? _testNotification
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF6A11CB),
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6),
                    ),
                    child: const Text('Test'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Data Management ─────────────────────
          _sectionHeader('🗄️ Data Management'),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red),
                  title: const Text(
                      'Clear All Activities',
                      style: TextStyle(
                          color: Colors.red)),
                  subtitle: const Text(
                      'Permanently delete all data'),
                  trailing:
                  const Icon(Icons.chevron_right),
                  onTap: () async {
                    await _vibrate();
                    _showClearDataConfirm();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── About ───────────────────────────────
          _sectionHeader('ℹ️ About'),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(12)),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info,
                      color: Color(0xFF6A11CB)),
                  title: Text('App Version'),
                  subtitle: Text('1.0.0'),
                ),
                const Divider(height: 0),
                const ListTile(
                  leading: Icon(Icons.storage,
                      color: Colors.green),
                  title: Text('Database'),
                  subtitle: Text('SQLite (local)'),
                ),
                const Divider(height: 0),
                const ListTile(
                  leading: Icon(Icons.cloud,
                      color: Colors.blue),
                  title: Text('APIs Used'),
                  subtitle: Text(
                      'Bored API + Quotable API'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}
