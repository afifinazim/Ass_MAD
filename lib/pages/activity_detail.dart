import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import '../models/activity.dart';
import '../helpers/database_helper.dart';
import 'add_activity.dart';

class ActivityDetailScreen extends StatefulWidget {
  final Activity activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState
    extends State<ActivityDetailScreen> {
  late Activity _activity;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }
  }

  Future<void> _refreshActivity() async {
    if (_activity.id == null) return;
    final updated =
    await DatabaseHelper.instance.getActivityById(_activity.id!);
    if (updated != null && mounted) {
      setState(() => _activity = updated);
    }
  }

  Future<void> _toggleComplete() async {
    await _vibrate();
    if (_activity.id == null) return;
    await DatabaseHelper.instance
        .toggleComplete(_activity.id!, !_activity.isCompleted);
    await _refreshActivity();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_activity.isCompleted
              ? '✅ Marked as completed!'
              : '↩️ Marked as incomplete'),
          backgroundColor: _activity.isCompleted
              ? Colors.green
              : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteActivity() async {
    await _vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text(
            'Are you sure you want to delete "${_activity.title}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _activity.id != null) {
      setState(() => _isDeleting = true);
      await DatabaseHelper.instance
          .deleteActivity(_activity.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Activity deleted'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _editActivity() async {
    await _vibrate();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddActivityScreen(activityToEdit: _activity),
      ),
    );
    if (result == true) {
      await _refreshActivity();
    }
  }

  Future<void> _shareActivity() async {
    await _vibrate();
    final text = '''
🎯 Extracurricular Activity

📌 Title: ${_activity.title}
🏷️ Category: ${_activity.category}
📅 Date: ${_activity.formattedDate}
⏱️ Hours: ${_activity.hours}h
✅ Status: ${_activity.isCompleted ? 'Completed' : 'In Progress'}
${_activity.steps != null && _activity.steps! > 0 ? '👣 Steps: ${_activity.steps}' : ''}
📝 Description: ${_activity.description}

Logged with Extracurricular Logger 📱
    '''.trim();

    await Share.share(text, subject: 'My Activity: ${_activity.title}');
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(_activity.category);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar with Image ─────────────────────────
          SliverAppBar(
            expandedHeight: _activity.imagePath != null &&
                _activity.imagePath!.isNotEmpty &&
                File(_activity.imagePath!).existsSync()
                ? 260.0
                : 160.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _activity.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          blurRadius: 8,
                          color: Colors.black54)
                    ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: _activity.imagePath != null &&
                  _activity.imagePath!.isNotEmpty &&
                  File(_activity.imagePath!).existsSync()
                  ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_activity.imagePath!),
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              )
                  : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withOpacity(0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                    _categoryIcon(_activity.category),
                    size: 80,
                    color: Colors.white.withOpacity(0.3)),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: _shareActivity,
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit',
                onPressed: _editActivity,
              ),
              IconButton(
                icon: _isDeleting
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2))
                    : const Icon(Icons.delete),
                tooltip: 'Delete',
                onPressed: _isDeleting ? null : _deleteActivity,
              ),
            ],
          ),

          // ─── Content ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + Complete button
                  _buildStatusCard(color),
                  const SizedBox(height: 16),

                  // Info grid
                  _buildInfoGrid(color),
                  const SizedBox(height: 16),

                  // Description
                  if (_activity.description.isNotEmpty) ...[
                    _buildSectionTitle('📝 Description'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius:
                        BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey[200]!),
                      ),
                      child: Text(
                        _activity.description,
                        style: const TextStyle(
                            fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Steps info
                  if (_activity.steps != null &&
                      _activity.steps! > 0) ...[
                    _buildSectionTitle('👣 Steps Logged'),
                    const SizedBox(height: 8),
                    _buildStepsCard(),
                    const SizedBox(height: 16),
                  ],

                  // Source link
                  if (_activity.sourceUrl != null &&
                      _activity.sourceUrl!.isNotEmpty) ...[
                    _buildSectionTitle('🔗 Source'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _activity.sourceUrl!,
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12),
                              maxLines: 2,
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  _buildActionButtons(color),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _activity.isCompleted
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _activity.isCompleted
                    ? Icons.check_circle
                    : Icons.pending,
                color: _activity.isCompleted
                    ? Colors.green
                    : Colors.orange,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activity.isCompleted
                        ? 'Completed'
                        : 'In Progress',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _activity.isCompleted
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  Text(
                    _activity.isCompleted
                        ? 'This activity has been completed'
                        : 'This activity is still ongoing',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _toggleComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: _activity.isCompleted
                    ? Colors.orange
                    : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              child: Text(
                _activity.isCompleted
                    ? 'Undo'
                    : 'Complete',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(Color color) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _infoTile(Icons.category, 'Category',
            _activity.category, color),
        _infoTile(Icons.access_time, 'Duration',
            '${_activity.hours} hour${_activity.hours > 1 ? 's' : ''}',
            Colors.blue),
        _infoTile(Icons.calendar_today, 'Date',
            _activity.formattedDate, Colors.purple),
        _infoTile(
            Icons.tag,
            'ID',
            '#${_activity.id ?? '—'}',
            Colors.grey),
      ],
    );
  }

  Widget _infoTile(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:
        Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    final steps = _activity.steps ?? 0;
    final goal = 10000;
    final progress = (steps / goal).clamp(0.0, 1.0);

    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text('$steps steps',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('/ $goal goal',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: Colors.green,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
                '${(progress * 100).toStringAsFixed(1)}% of daily goal',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold));
  }

  Widget _buildActionButtons(Color color) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareActivity,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6A11CB),
              side: const BorderSide(
                  color: Color(0xFF6A11CB)),
              padding:
              const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _editActivity,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A11CB),
              foregroundColor: Colors.white,
              padding:
              const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
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
