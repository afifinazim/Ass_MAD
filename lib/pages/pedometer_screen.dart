import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:vibration/vibration.dart';
import '../helpers/preferences_helper.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';

class PedometerScreen extends StatefulWidget {
  const PedometerScreen({super.key});

  @override
  State<PedometerScreen> createState() =>
      _PedometerScreenState();
}

class _PedometerScreenState extends State<PedometerScreen>
    with WidgetsBindingObserver {
  // ─── Pedometer streams ───────────────────────────────────
  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;

  // ─── State ───────────────────────────────────────────────
  int _steps = 0;
  int _sessionSteps = 0;   // steps since screen opened
  int _baselineSteps = 0;  // raw step count at session start
  int _dailyGoal = 10000;
  String _status = 'stopped'; // walking / stopped
  bool _isTracking = false;
  bool _isLoading = true;
  bool _goalNotified = false;

  // ─── History ─────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    _dailyGoal =
    await PreferencesHelper.instance.getPedometerGoal();
    await _loadHistory();
    setState(() => _isLoading = false);
  }

  Future<void> _loadHistory() async {
    // Load last 7 activities that have steps > 0
    final activities =
    await DatabaseHelper.instance.getAllActivities();
    final withSteps = activities
        .where((a) => a.steps != null && a.steps! > 0)
        .take(7)
        .toList();

    setState(() {
      _history = withSteps
          .map((a) => {
        'title': a.title,
        'steps': a.steps!,
        'date': a.formattedDate,
        'category': a.category,
      })
          .toList();
    });
  }

  // ─── Start Tracking ───────────────────────────────────────
  void _startTracking() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 60);
    }

    setState(() {
      _isTracking = true;
      _sessionSteps = 0;
      _goalNotified = false;
    });

    // Step count stream
    _stepSub = Pedometer.stepCountStream.listen(
          (StepCount event) {
        if (_baselineSteps == 0) {
          _baselineSteps = event.steps;
        }
        final session = event.steps - _baselineSteps;
        setState(() {
          _steps = event.steps;
          _sessionSteps = session < 0 ? 0 : session;
        });

        // Notify when goal reached
        if (_sessionSteps >= _dailyGoal && !_goalNotified) {
          _goalNotified = true;
          _onGoalReached();
        }
      },
      onError: (error) {
        setState(() => _status = 'unavailable');
      },
      cancelOnError: false,
    );

    // Pedestrian status stream
    _statusSub =
        Pedometer.pedestrianStatusStream.listen(
              (PedestrianStatus event) {
            setState(() => _status = event.status);
          },
          onError: (_) {
            setState(() => _status = 'unavailable');
          },
          cancelOnError: false,
        );
  }

  // ─── Stop Tracking ────────────────────────────────────────
  void _stopTracking() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    await _stepSub?.cancel();
    await _statusSub?.cancel();
    _stepSub = null;
    _statusSub = null;
    _baselineSteps = 0;

    setState(() {
      _isTracking = false;
      _status = 'stopped';
    });

    if (_sessionSteps > 0) {
      _showSaveDialog();
    }
  }

  Future<void> _onGoalReached() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
          pattern: [0, 200, 100, 200, 100, 400]);
    }
    final notifEnabled = await PreferencesHelper.instance
        .getNotificationsEnabled();
    if (notifEnabled) {
      await NotificationHelper.instance
          .showPedometerGoalNotification(_sessionSteps);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                  '🎉 Goal reached! $_sessionSteps steps!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ─── Save Steps Dialog ────────────────────────────────────
  void _showSaveDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SaveStepsSheet(
        steps: _sessionSteps,
        onSave: (activityId) async {
          if (activityId != null) {
            await DatabaseHelper.instance
                .updateSteps(activityId, _sessionSteps);
            await _loadHistory();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                  Text('✅ Steps saved to activity!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
          setState(() => _sessionSteps = 0);
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isTracking) {
      // Keep tracking in background
    }
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
    (_sessionSteps / _dailyGoal).clamp(0.0, 1.0);
    final remaining =
    (_dailyGoal - _sessionSteps).clamp(0, _dailyGoal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Step Counter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isTracking) _stopTracking();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh history',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Main tracker card ───────────────
            _buildTrackerCard(progress, remaining),
            const SizedBox(height: 16),

            // ── Status card ─────────────────────
            _buildStatusCard(),
            const SizedBox(height: 16),

            // ── Stats row ───────────────────────
            _buildStatsRow(),
            const SizedBox(height: 16),

            // ── Control button ──────────────────
            _buildControlButton(),
            const SizedBox(height: 24),

            // ── Info card ───────────────────────
            _buildInfoCard(),
            const SizedBox(height: 16),

            // ── History ─────────────────────────
            _buildHistory(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Tracker Card ─────────────────────────────────────────
  Widget _buildTrackerCard(double progress, int remaining) {
    final goalReached = _sessionSteps >= _dailyGoal;
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: goalReached
                ? [Colors.green.shade400, Colors.green.shade700]
                : _isTracking
                ? [
              const Color(0xFF6A11CB),
              const Color(0xFF2575FC)
            ]
                : [Colors.grey.shade400, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Steps count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_sessionSteps',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    ' steps',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              goalReached
                  ? '🎉 Daily goal reached!'
                  : '$remaining steps to goal',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Progress ring (circular-ish with linear)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                    Colors.white.withOpacity(0.25),
                    color: goalReached
                        ? Colors.amber
                        : Colors.white,
                    minHeight: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('0',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12)),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    Text(
                      '$_dailyGoal',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status Card ──────────────────────────────────────────
  Widget _buildStatusCard() {
    final isWalking = _status == 'walking';
    final isUnavailable = _status == 'unavailable';

    IconData icon;
    String label;
    Color color;

    if (isUnavailable) {
      icon = Icons.error_outline;
      label = 'Sensor unavailable on this device';
      color = Colors.red;
    } else if (!_isTracking) {
      icon = Icons.pause_circle;
      label = 'Tracking stopped';
      color = Colors.grey;
    } else if (isWalking) {
      icon = Icons.directions_walk;
      label = 'Walking detected 🚶';
      color = Colors.green;
    } else {
      icon = Icons.accessibility_new;
      label = 'Standing still';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────
  Widget _buildStatsRow() {
    final calories =
    (_sessionSteps * 0.04).toStringAsFixed(1);
    final distanceKm =
    (_sessionSteps * 0.000762).toStringAsFixed(2);

    return Row(
      children: [
        _statTile('🔥 Calories', '~$calories kcal',
            Colors.orange),
        const SizedBox(width: 10),
        _statTile(
            '📏 Distance', '~$distanceKm km', Colors.blue),
        const SizedBox(width: 10),
        _statTile('🎯 Goal', '$_dailyGoal steps', Colors.purple),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border:
          Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── Control Button ───────────────────────────────────────
  Widget _buildControlButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed:
        _isTracking ? _stopTracking : _startTracking,
        icon: Icon(
          _isTracking ? Icons.stop : Icons.play_arrow,
          size: 24,
        ),
        label: Text(
          _isTracking ? 'Stop & Save' : 'Start Tracking',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
          _isTracking ? Colors.red : const Color(0xFF6A11CB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 4,
        ),
      ),
    );
  }

  // ─── Info Card ────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Text('How it works',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1. Tap "Start Tracking" to begin counting steps.\n'
                '2. Walk around with your phone in your pocket or hand.\n'
                '3. Tap "Stop & Save" to attach steps to an activity.\n'
                '4. Steps are saved in your activity log.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── History ──────────────────────────────────────────────
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('👣 Step History',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _history.isEmpty
            ? Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: Colors.grey[200]!),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.directions_walk,
                    size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                    'No step history yet.\nStart tracking to record your steps!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13)),
              ],
            ),
          ),
        )
            : Column(
          children: _history.map((h) {
            final color =
            _categoryColor(h['category']);
            return Card(
              margin:
              const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                    color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions_walk,
                      color: color, size: 22),
                ),
                title: Text(h['title'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(h['date'],
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600])),
                trailing: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text('${h['steps']}',
                        style: const TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 16)),
                    Text('steps',
                        style: TextStyle(
                            fontSize: 10,
                            color:
                            Colors.grey[500])),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
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
}

// ─── Save Steps Bottom Sheet ──────────────────────────────────

class _SaveStepsSheet extends StatefulWidget {
  final int steps;
  final Function(int?) onSave;

  const _SaveStepsSheet(
      {required this.steps, required this.onSave});

  @override
  State<_SaveStepsSheet> createState() =>
      _SaveStepsSheetState();
}

class _SaveStepsSheetState extends State<_SaveStepsSheet> {
  List<Map<String, dynamic>> _activities = [];
  int? _selectedId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final list =
    await DatabaseHelper.instance.getAllActivities();
    setState(() {
      _activities = list
          .take(20)
          .map((a) => {
        'id': a.id,
        'title': a.title,
        'category': a.category,
        'date': a.formattedDate,
      })
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.save_alt,
                  color: Color(0xFF6A11CB)),
              const SizedBox(width: 8),
              const Text('Save Steps to Activity',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.steps} steps',
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select an activity to attach these steps to:',
            style: TextStyle(
                color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Activity list
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator())
          else if (_activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No activities found. Add an activity first.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                  maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _activities.length,
                itemBuilder: (_, i) {
                  final a = _activities[i];
                  final isSelected =
                      _selectedId == a['id'];
                  return RadioListTile<int>(
                    value: a['id'] as int,
                    groupValue: _selectedId,
                    activeColor: const Color(0xFF6A11CB),
                    title: Text(a['title'],
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${a['category']} • ${a['date']}',
                        style: const TextStyle(
                            fontSize: 11)),
                    selected: isSelected,
                    tileColor: isSelected
                        ? const Color(0xFF6A11CB)
                        .withOpacity(0.06)
                        : null,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(8)),
                    onChanged: (v) =>
                        setState(() => _selectedId = v),
                  );
                },
              ),
            ),

          const SizedBox(height: 14),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onSave(null);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _selectedId == null
                      ? null
                      : () {
                    widget.onSave(_selectedId);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save Steps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF6A11CB),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    Colors.grey[300],
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
