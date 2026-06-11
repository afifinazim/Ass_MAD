import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import '../helpers/preferences_helper.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() =>
      _AchievementsScreenState();
}

class _AchievementsScreenState
    extends State<AchievementsScreen> {
  bool _isLoading = true;
  List<_Achievement> _achievements = [];
  int _unlocked = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final totalActivities =
    await DatabaseHelper.instance.getTotalActivities();
    final totalHours =
    await DatabaseHelper.instance.getTotalHours();
    final rate =
    await DatabaseHelper.instance.getCompletionRate();
    final byCategory =
    await DatabaseHelper.instance.getHoursByCategory();
    final goal =
    await PreferencesHelper.instance.getMonthlyGoal();
    final totalSteps =
    await DatabaseHelper.instance.getTotalSteps();
    final notifEnabled =
    await PreferencesHelper.instance
        .getNotificationsEnabled();
    final allActivities =
    await DatabaseHelper.instance.getAllActivities();

    final now = DateTime.now();
    final thisWeekCount = allActivities
        .where((a) => now.difference(a.date).inDays < 7)
        .length;

    final achievements = _buildAchievements(
      totalActivities: totalActivities,
      totalHours: totalHours,
      completionRate: rate,
      categoryCount: byCategory.keys.length,
      monthlyGoal: goal,
      thisWeekCount: thisWeekCount,
      totalSteps: totalSteps,
    );

    // Notify newly unlocked achievements
    if (notifEnabled) {
      for (final a in achievements) {
        if (a.unlocked) {
          await NotificationHelper.instance
              .showAchievementNotification(a.title);
        }
      }
    }

    final unlockedCount =
        achievements.where((a) => a.unlocked).length;

    setState(() {
      _achievements = achievements;
      _unlocked = unlockedCount;
      _isLoading = false;
    });
  }

  List<_Achievement> _buildAchievements({
    required int totalActivities,
    required int totalHours,
    required double completionRate,
    required int categoryCount,
    required int monthlyGoal,
    required int thisWeekCount,
    required int totalSteps,
  }) {
    return [
      _Achievement(
        title: 'First Step',
        description: 'Log your very first activity',
        icon: Icons.star,
        color: Colors.amber,
        unlocked: totalActivities >= 1,
        progress: totalActivities / 1,
        progressLabel: '$totalActivities / 1 activities',
      ),
      _Achievement(
        title: 'Getting Started',
        description: 'Log 5 activities',
        icon: Icons.rocket_launch,
        color: Colors.blue,
        unlocked: totalActivities >= 5,
        progress: totalActivities / 5,
        progressLabel: '$totalActivities / 5 activities',
      ),
      _Achievement(
        title: 'Activity Pro',
        description: 'Log 15 activities',
        icon: Icons.workspace_premium,
        color: Colors.purple,
        unlocked: totalActivities >= 15,
        progress: totalActivities / 15,
        progressLabel: '$totalActivities / 15 activities',
      ),
      _Achievement(
        title: 'Time Keeper',
        description: 'Log 10 total hours',
        icon: Icons.access_time,
        color: Colors.green,
        unlocked: totalHours >= 10,
        progress: totalHours / 10,
        progressLabel: '$totalHours / 10 hours',
      ),
      _Achievement(
        title: 'Half Century',
        description: 'Log 50 total hours',
        icon: Icons.military_tech,
        color: Colors.orange,
        unlocked: totalHours >= 50,
        progress: totalHours / 50,
        progressLabel: '$totalHours / 50 hours',
      ),
      _Achievement(
        title: 'Century Club',
        description: 'Log 100 total hours',
        icon: Icons.emoji_events,
        color: Colors.red,
        unlocked: totalHours >= 100,
        progress: totalHours / 100,
        progressLabel: '$totalHours / 100 hours',
      ),
      _Achievement(
        title: 'Explorer',
        description: 'Try 3 different categories',
        icon: Icons.explore,
        color: Colors.teal,
        unlocked: categoryCount >= 3,
        progress: categoryCount / 3,
        progressLabel: '$categoryCount / 3 categories',
      ),
      _Achievement(
        title: 'All Rounder',
        description: 'Try all 5 categories',
        icon: Icons.all_inclusive,
        color: Colors.indigo,
        unlocked: categoryCount >= 5,
        progress: categoryCount / 5,
        progressLabel: '$categoryCount / 5 categories',
      ),
      _Achievement(
        title: 'Perfect Record',
        description: 'Reach 80% completion rate',
        icon: Icons.check_circle,
        color: Colors.green,
        unlocked: completionRate >= 0.8,
        progress: completionRate / 0.8,
        progressLabel:
        '${(completionRate * 100).toInt()}% / 80%',
      ),
      _Achievement(
        title: 'Goal Crusher',
        description: 'Reach your monthly hour goal',
        icon: Icons.flag,
        color: Colors.pink,
        unlocked: totalHours >= monthlyGoal,
        progress:
        monthlyGoal > 0 ? totalHours / monthlyGoal : 0,
        progressLabel: '$totalHours / $monthlyGoal hours',
      ),
      _Achievement(
        title: 'Weekly Warrior',
        description: 'Log 3+ activities in one week',
        icon: Icons.calendar_today,
        color: Colors.cyan,
        unlocked: thisWeekCount >= 3,
        progress: thisWeekCount / 3,
        progressLabel: '$thisWeekCount / 3 this week',
      ),
      _Achievement(
        title: 'Consistent',
        description: 'Log 10+ activities in one week',
        icon: Icons.local_fire_department,
        color: Colors.deepOrange,
        unlocked: thisWeekCount >= 10,
        progress: thisWeekCount / 10,
        progressLabel: '$thisWeekCount / 10 this week',
      ),
      // New: Steps achievements
      _Achievement(
        title: 'Walker',
        description: 'Log 5,000 total steps',
        icon: Icons.directions_walk,
        color: Colors.lightGreen,
        unlocked: totalSteps >= 5000,
        progress: totalSteps / 5000,
        progressLabel: '$totalSteps / 5,000 steps',
      ),
      _Achievement(
        title: 'Marathoner',
        description: 'Log 50,000 total steps',
        icon: Icons.directions_run,
        color: Colors.green,
        unlocked: totalSteps >= 50000,
        progress: totalSteps / 50000,
        progressLabel: '$totalSteps / 50,000 steps',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lockedList =
    _achievements.where((a) => !a.unlocked).toList();
    final unlockedList =
    _achievements.where((a) => a.unlocked).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _vibrate();
              _load();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Summary header
          _buildHeader(),
          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    16, 8, 16, 16),
                children: [
                  if (unlockedList.isNotEmpty) ...[
                    _listHeader(
                        '🏆 Unlocked (${unlockedList.length})',
                        Colors.green),
                    const SizedBox(height: 8),
                    ...unlockedList
                        .map(_buildCard)
                        .toList(),
                    const SizedBox(height: 12),
                  ],
                  if (lockedList.isNotEmpty) ...[
                    _listHeader(
                        '🔒 Locked (${lockedList.length})',
                        Colors.grey),
                    const SizedBox(height: 8),
                    ...lockedList
                        .map(_buildCard)
                        .toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pct = _achievements.isEmpty
        ? 0.0
        : _unlocked / _achievements.length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events,
              size: 48, color: Colors.amber),
          const SizedBox(height: 8),
          Text(
            '$_unlocked / ${_achievements.length}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold),
          ),
          const Text(
            'Achievements Unlocked',
            style: TextStyle(
                color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor:
              Colors.white.withOpacity(0.3),
              color: Colors.amber,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% complete',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _listHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildCard(_Achievement a) {
    return GestureDetector(
      onTap: a.unlocked ? _vibrate : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: a.unlocked ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: a.unlocked
              ? BorderSide(
              color: a.color.withOpacity(0.4),
              width: 1.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: a.unlocked
                      ? a.color.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(a.icon,
                    color: a.unlocked
                        ? a.color
                        : Colors.grey,
                    size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(a.title,
                              style: TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 14,
                                color: a.unlocked
                                    ? null
                                    : Colors.grey,
                              )),
                        ),
                        if (a.unlocked)
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green
                                  .withOpacity(0.12),
                              borderRadius:
                              BorderRadius.circular(
                                  20),
                            ),
                            child: const Text('✓ Unlocked',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight:
                                    FontWeight.bold)),
                          )
                        else
                          Icon(Icons.lock,
                              size: 15,
                              color: Colors.grey[400]),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(a.description,
                        style: TextStyle(
                            fontSize: 12,
                            color: a.unlocked
                                ? Colors.grey[600]
                                : Colors.grey[400])),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:
                        a.progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        color: a.unlocked
                            ? a.color
                            : Colors.grey[400]!,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(a.progressLabel,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500])),
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

class _Achievement {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool unlocked;
  final double progress;
  final String progressLabel;

  const _Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.unlocked,
    required this.progress,
    required this.progressLabel,
  });
}
