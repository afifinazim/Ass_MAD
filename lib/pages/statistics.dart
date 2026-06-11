import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:vibration/vibration.dart';
import '../helpers/database_helper.dart';
import '../helpers/preferences_helper.dart';
import '../models/activity.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() =>
      _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  int _totalHours = 0;
  int _totalActivities = 0;
  double _completionRate = 0;
  int _monthlyGoal = 50;
  int _totalSteps = 0;
  Map<String, int> _hoursByCategory = {};
  Map<String, int> _weeklyData = {};
  Map<String, int> _monthlyData = {};
  List<Activity> _allActivities = [];
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final activities =
      await DatabaseHelper.instance.getAllActivities();
      final hours =
      await DatabaseHelper.instance.getTotalHours();
      final rate =
      await DatabaseHelper.instance.getCompletionRate();
      final byCategory =
      await DatabaseHelper.instance.getHoursByCategory();
      final goal =
      await PreferencesHelper.instance.getMonthlyGoal();
      final steps =
      await DatabaseHelper.instance.getTotalSteps();
      final monthly =
      await DatabaseHelper.instance.getActivitiesPerMonth();

      setState(() {
        _allActivities = activities;
        _totalActivities = activities.length;
        _totalHours = hours;
        _completionRate = rate;
        _hoursByCategory = byCategory;
        _monthlyGoal = goal;
        _totalSteps = steps;
        _weeklyData = _buildWeeklyData(activities);
        _monthlyData = monthly;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, int> _buildWeeklyData(List<Activity> activities) {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final Map<String, int> data = {for (var d in days) d: 0};
    for (final a in activities) {
      final diff = now.difference(a.date).inDays;
      if (diff < 7) {
        final dayName = days[a.date.weekday - 1];
        data[dayName] = (data[dayName] ?? 0) + a.hours;
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _vibrate();
              _loadStats();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Charts'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _totalActivities == 0
          ? _buildEmpty()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildChartsTab(),
          _buildMonthlyTab(),
        ],
      ),
    );
  }

  // ─── Overview Tab ─────────────────────────────────────────
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryGrid(),
            const SizedBox(height: 16),
            _buildMonthlyProgressCard(),
            const SizedBox(height: 16),
            _buildCompletionCard(),
            const SizedBox(height: 16),
            _buildStepsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final avgHours = _totalActivities > 0
        ? (_totalHours / _totalActivities).toStringAsFixed(1)
        : '0';
    final completed =
    (_completionRate * _totalActivities).round();
    final cats = _hoursByCategory.keys.length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _summaryTile('Total Activities', '$_totalActivities',
            Icons.list_alt, Colors.blue),
        _summaryTile('Total Hours', '${_totalHours}h',
            Icons.access_time, Colors.green),
        _summaryTile('Avg per Activity', '${avgHours}h',
            Icons.timeline, Colors.orange),
        _summaryTile('Completed', '$completed',
            Icons.check_circle, Colors.purple),
        _summaryTile('Categories Used', '$cats',
            Icons.category, Colors.teal),
        _summaryTile('Total Steps', '$_totalSteps',
            Icons.directions_walk, Colors.pink),
      ],
    );
  }

  Widget _summaryTile(String label, String value,
      IconData icon, Color color) {
    return GestureDetector(
      onTap: _vibrate,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border:
          Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyProgressCard() {
    final pct =
    (_totalHours / _monthlyGoal).clamp(0.0, 1.0);
    return Card(
      elevation: 3,
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
                const Text('📈 Monthly Goal',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text(
                  '$_totalHours / $_monthlyGoal hrs',
                  style: const TextStyle(
                      color: Color(0xFF6A11CB),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.grey[200],
                color: pct >= 1.0
                    ? Colors.green
                    : const Color(0xFF6A11CB),
                minHeight: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(1)}% completed',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600]),
                ),
                if (pct >= 1.0)
                  const Text('🎉 Goal reached!',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    final completed =
    (_completionRate * _totalActivities).round();
    final pending = _totalActivities - completed;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Completion Rate',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceAround,
              children: [
                _completionStat(
                    'Completed', '$completed', Colors.green),
                _completionStat(
                    'Pending', '$pending', Colors.orange),
                _completionStat(
                    'Rate',
                    '${(_completionRate * 100).toInt()}%',
                    Colors.blue),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _completionRate,
                backgroundColor: Colors.orange[100],
                color: Colors.green,
                minHeight: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completionStat(
      String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStepsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.pink.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_walk,
                  color: Colors.pink, size: 28),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_totalSteps',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const Text('Total Steps Logged',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Charts Tab ───────────────────────────────────────────
  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_hoursByCategory.isNotEmpty) ...[
            _sectionTitle('🍕 Hours by Category'),
            const SizedBox(height: 12),
            _buildPieChart(),
            const SizedBox(height: 20),
          ],
          _sectionTitle('📅 This Week\'s Hours'),
          const SizedBox(height: 12),
          _buildBarChart(),
          const SizedBox(height: 20),
          _sectionTitle('📊 Category Breakdown'),
          const SizedBox(height: 12),
          _buildCategoryList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final entries = _hoursByCategory.entries.toList();
    final total =
    entries.fold(0, (sum, e) => sum + e.value);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event
                            .isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection ==
                                null) {
                          _touchedPieIndex = -1;
                          return;
                        }
                        _touchedPieIndex = response
                            .touchedSection!
                            .touchedSectionIndex;
                      });
                    },
                  ),
                  sections:
                  entries.asMap().entries.map((e) {
                    final touched =
                        e.key == _touchedPieIndex;
                    final pct = total > 0
                        ? (e.value.value / total * 100)
                        .toStringAsFixed(1)
                        : '0';
                    return PieChartSectionData(
                      value: e.value.value.toDouble(),
                      color:
                      _categoryColor(e.value.key),
                      radius: touched ? 68.0 : 55.0,
                      title: touched
                          ? '${e.value.key}\n$pct%'
                          : '$pct%',
                      titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    );
                  }).toList(),
                  centerSpaceRadius: 38,
                  sectionsSpace: 3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _categoryColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('${e.key} (${e.value}h)',
                        style:
                        const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    final maxY = _weeklyData.values.isEmpty
        ? 8.0
        : (_weeklyData.values.reduce((a, b) => a > b ? a : b) +
        2)
        .toDouble();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) =>
                      BarTooltipItem(
                        '${rod.toY.toInt()}h',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles:
                    SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles:
                    SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(days[v.toInt()],
                          style: const TextStyle(
                              fontSize: 11)),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}h',
                        style: const TextStyle(
                            fontSize: 10)),
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.withOpacity(0.2),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: days.asMap().entries.map((e) {
                final h = _weeklyData[e.value] ?? 0;
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: h.toDouble(),
                      color: const Color(0xFF6A11CB),
                      width: 18,
                      borderRadius:
                      BorderRadius.circular(4),
                      backDrawRodData:
                      BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color:
                        Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_hoursByCategory.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No data yet')));
    }
    final total =
    _hoursByCategory.values.fold(0, (a, b) => a + b);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _hoursByCategory.entries.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            final color = _categoryColor(e.key);
            return Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(e.key,
                              style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w500)),
                        ],
                      ),
                      Text(
                        '${e.value}h  (${(pct * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey[200],
                      color: color,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Monthly Tab ──────────────────────────────────────────
  Widget _buildMonthlyTab() {
    if (_monthlyData.isEmpty) {
      return Center(
        child: Text('No monthly data yet',
            style: TextStyle(color: Colors.grey[500])),
      );
    }

    final entries = _monthlyData.entries.toList().reversed.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sectionTitle('📆 Activities per Month'),
          const SizedBox(height: 12),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: entries.map((e) {
                  final month = _formatMonth(e.key);
                  final max = entries.isEmpty
                      ? 1
                      : entries
                      .map((x) => x.value)
                      .reduce((a, b) => a > b ? a : b);
                  final pct = max > 0
                      ? e.value / max
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(month,
                                style: const TextStyle(
                                    fontWeight:
                                    FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                                '${e.value} activit${e.value == 1 ? 'y' : 'ies'}',
                                style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor:
                            Colors.grey[200],
                            color:
                            const Color(0xFF6A11CB),
                            minHeight: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatMonth(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      final year = parts[0];
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = int.tryParse(parts[1]) ?? 1;
      return '${months[month]} $year';
    } catch (_) {
      return yyyyMM;
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No statistics yet',
              style: TextStyle(
                  fontSize: 18, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Add some activities to see your stats here',
              style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold));

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
}
