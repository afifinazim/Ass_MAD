import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../helpers/database_helper.dart';
import '../helpers/preferences_helper.dart';
import '../models/activity.dart';
import '../main.dart';
import 'activity_log.dart';
import 'add_activity.dart';
import 'statistics.dart';
import 'achievements.dart';
import 'profile.dart';
import 'settings.dart';
import 'api_suggestion.dart';
import 'activity_detail.dart';
import 'pedometer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Activity> _recentActivities = [];
  int _totalHours = 0;
  int _totalActivities = 0;
  int _totalCategories = 0;
  double _completionRate = 0;
  int _monthlyGoal = 50;
  String _userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final activities =
      await DatabaseHelper.instance.getAllActivities();
      final hours = await DatabaseHelper.instance.getTotalHours();
      final rate =
      await DatabaseHelper.instance.getCompletionRate();
      final goal =
      await PreferencesHelper.instance.getMonthlyGoal();
      final profile =
      await PreferencesHelper.instance.getProfile();
      final Set<String> cats = {for (var a in activities) a.category};

      setState(() {
        _recentActivities = activities.take(3).toList();
        _totalHours = hours;
        _totalActivities = activities.length;
        _totalCategories = cats.length;
        _completionRate = rate;
        _monthlyGoal = goal;
        _userName = profile['name'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
  }

  void _navigate(Widget page) async {
    await _vibrate();
    if (!mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => page));
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracurricular Logger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Activity Explorer',
            onPressed: () => _navigate(const ApiSuggestionsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.directions_walk),
            tooltip: 'Pedometer',
            onPressed: () => _navigate(const PedometerScreen()),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildStatsRow(),
              _buildMonthlyProgress(),
              _buildQuickActions(),
              _buildRecentActivities(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _vibrate();
          if (!mounted) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddActivityScreen()),
          );
          if (result == true) _loadData();
        },
        backgroundColor: const Color(0xFF6A11CB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Activity',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny,
                  color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text(
                '$greeting${_userName.isNotEmpty ? ', $_userName' : ''}!',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '🎯 Extracurricular Logger',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Track activities · Earn achievements · Grow',
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 16),
          // Completion badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${(_completionRate * 100).toInt()}% completion rate',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          _statCard('Activities', '$_totalActivities',
              Icons.list_alt,
              [const Color(0xFF6A11CB), const Color(0xFF2575FC)]),
          const SizedBox(width: 10),
          _statCard('Hours', '${_totalHours}h',
              Icons.access_time,
              [const Color(0xFF11998E), const Color(0xFF38A2D7)]),
          const SizedBox(width: 10),
          _statCard('Categories', '$_totalCategories',
              Icons.category,
              [const Color(0xFFF46B45), const Color(0xFFEEA849)]),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon,
      List<Color> colors) {
    return Expanded(
      child: GestureDetector(
        onTap: _vibrate,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Monthly Progress ─────────────────────────────────────
  Widget _buildMonthlyProgress() {
    final percent =
    (_totalHours / _monthlyGoal).clamp(0.0, 1.0);
    final remaining =
    (_monthlyGoal - _totalHours).clamp(0, _monthlyGoal);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text('📈 Monthly Goal Progress',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: percent >= 1.0
                          ? Colors.green.withOpacity(0.1)
                          : const Color(0xFF6A11CB)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      percent >= 1.0
                          ? '🎉 Completed!'
                          : '$remaining h left',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: percent >= 1.0
                              ? Colors.green
                              : const Color(0xFF6A11CB)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_totalHours hours logged',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13)),
                  Text('Goal: $_monthlyGoal hours',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: Colors.grey[200],
                  color: percent >= 1.0
                      ? Colors.green
                      : const Color(0xFF6A11CB),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(percent * 100).toStringAsFixed(1)}% completed',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚡ Quick Actions',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _quickActionCard(
                icon: Icons.lightbulb,
                label: 'Explore\nActivities',
                color: const Color(0xFF2575FC),
                onTap: () =>
                    _navigate(const ApiSuggestionsScreen()),
              ),
              const SizedBox(width: 10),
              _quickActionCard(
                icon: Icons.directions_walk,
                label: 'Step\nCounter',
                color: const Color(0xFF11998E),
                onTap: () =>
                    _navigate(const PedometerScreen()),
              ),
              const SizedBox(width: 10),
              _quickActionCard(
                icon: Icons.bar_chart,
                label: 'View\nStats',
                color: const Color(0xFFF46B45),
                onTap: () =>
                    _navigate(const StatisticsScreen()),
              ),
              const SizedBox(width: 10),
              _quickActionCard(
                icon: Icons.emoji_events,
                label: 'Achieve-\nments',
                color: Colors.amber.shade700,
                onTap: () =>
                    _navigate(const AchievementsScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await _vibrate();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Recent Activities ────────────────────────────────────
  Widget _buildRecentActivities() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📋 Recent Activities',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () =>
                    _navigate(const ActivityLogScreen()),
                child: const Text('View All →',
                    style:
                    TextStyle(color: Color(0xFF6A11CB))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentActivities.isEmpty)
            _buildEmptyState()
          else
            ..._recentActivities
                .map(_buildActivityCard)
                .toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('No activities yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Tap the button below to add your first one!',
              style:
              TextStyle(fontSize: 12, color: Colors.grey[400]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    final color = _categoryColor(activity.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await _vibrate();
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ActivityDetailScreen(activity: activity),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: activity.imagePath != null &&
                    activity.imagePath!.isNotEmpty &&
                    File(activity.imagePath!).existsSync()
                    ? Image.file(
                  File(activity.imagePath!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                )
                    : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.7)
                      ],
                    ),
                  ),
                  child: Icon(
                      _categoryIcon(activity.category),
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(activity.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                        '${activity.category} • ${activity.hours}h • ${activity.formattedDate}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(
                activity.isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: activity.isCompleted
                    ? Colors.green
                    : Colors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Drawer ───────────────────────────────────────────────
  Drawer _buildDrawer(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC)
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person,
                      size: 36, color: Color(0xFF6A11CB)),
                ),
                const SizedBox(height: 10),
                Text(
                  _userName.isNotEmpty
                      ? _userName
                      : 'Student Portal',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_totalActivities activities · ${_totalHours}h',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          _drawerItem(Icons.home, 'Home',
                  () => Navigator.pop(context), isActive: true),
          _drawerItem(Icons.list, 'Activity Log', () {
            Navigator.pop(context);
            _navigate(const ActivityLogScreen());
          }),
          _drawerItem(Icons.lightbulb, 'Activity Explorer', () {
            Navigator.pop(context);
            _navigate(const ApiSuggestionsScreen());
          }),
          _drawerItem(Icons.directions_walk, 'Pedometer', () {
            Navigator.pop(context);
            _navigate(const PedometerScreen());
          }),
          _drawerItem(Icons.bar_chart, 'Statistics', () {
            Navigator.pop(context);
            _navigate(const StatisticsScreen());
          }),
          _drawerItem(Icons.emoji_events, 'Achievements', () {
            Navigator.pop(context);
            _navigate(const AchievementsScreen());
          }),
          const Divider(),
          _drawerItem(Icons.person, 'Profile', () {
            Navigator.pop(context);
            _navigate(const ProfileScreen());
          }),
          _drawerItem(Icons.settings, 'Settings', () {
            Navigator.pop(context);
            _navigate(const SettingsScreen());
          }),
          const Divider(),
          // Dark mode toggle in drawer
          ListTile(
            leading: Icon(
              themeProvider.isDarkMode
                  ? Icons.dark_mode
                  : Icons.light_mode,
              color: const Color(0xFF6A11CB),
            ),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: themeProvider.isDarkMode,
              activeColor: const Color(0xFF6A11CB),
              onChanged: (v) => themeProvider.toggleTheme(v),
            ),
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(
      IconData icon, String title, VoidCallback onTap,
      {bool isActive = false}) {
    return ListTile(
      leading: Icon(icon,
          color: isActive
              ? const Color(0xFF6A11CB)
              : Colors.grey[700]),
      title: Text(title,
          style: TextStyle(
              color: isActive
                  ? const Color(0xFF6A11CB)
                  : null,
              fontWeight: isActive
                  ? FontWeight.bold
                  : FontWeight.normal)),
      tileColor: isActive
          ? const Color(0xFF6A11CB).withOpacity(0.08)
          : null,
      onTap: onTap,
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) async {
        await _vibrate();
        setState(() => _selectedIndex = 0);
        switch (index) {
          case 1:
            _navigate(const ActivityLogScreen());
            break;
          case 2:
            _navigate(const StatisticsScreen());
            break;
          case 3:
            _navigate(const ProfileScreen());
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.list_alt), label: 'Log'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart), label: 'Stats'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'sports': return Colors.blue;
      case 'academic': return Colors.green;
      case 'arts': return Colors.purple;
      case 'volunteer': return Colors.orange;
      case 'leadership': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'sports': return Icons.sports_soccer;
      case 'academic': return Icons.school;
      case 'arts': return Icons.palette;
      case 'volunteer': return Icons.volunteer_activism;
      case 'leadership': return Icons.star;
      default: return Icons.category;
    }
  }
}
