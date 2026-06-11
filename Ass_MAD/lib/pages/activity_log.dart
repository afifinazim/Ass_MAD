import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../models/activity.dart';
import '../helpers/database_helper.dart';
import 'add_activity.dart';
import 'activity_detail.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() =>
      _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<Activity> _activities = [];
  List<Activity> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController =
  TextEditingController();
  String _selectedCategory = 'All';
  String _sortBy = 'date';
  bool _sortDesc = true;

  final List<String> _categories = [
    'All', 'Sports', 'Academic', 'Arts',
    'Volunteer', 'Leadership', 'Other',
  ];

  final Map<String, String> _sortOptions = {
    'date': 'Date',
    'title': 'Title',
    'hours': 'Hours',
  };

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 40);
    }
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final activities =
      await DatabaseHelper.instance.getAllActivities(
        sortBy: _sortBy,
        descending: _sortDesc,
      );
      setState(() {
        _activities = activities;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activities: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _activities.where((a) {
        final matchSearch = query.isEmpty ||
            a.title.toLowerCase().contains(query) ||
            a.category.toLowerCase().contains(query) ||
            a.description.toLowerCase().contains(query);
        final matchCat = _selectedCategory == 'All' ||
            a.category == _selectedCategory;
        return matchSearch && matchCat;
      }).toList();
    });
  }

  Future<void> _deleteActivity(Activity activity) async {
    await _vibrate();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Delete "${activity.title}"?\nThis cannot be undone.'),
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
    if (confirmed == true && activity.id != null) {
      await DatabaseHelper.instance
          .deleteActivity(activity.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Activity deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _loadActivities();
    }
  }

  Future<void> _toggleComplete(Activity activity) async {
    await _vibrate();
    if (activity.id == null) return;
    await DatabaseHelper.instance
        .toggleComplete(activity.id!, !activity.isCompleted);
    _loadActivities();
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort By',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._sortOptions.entries.map((e) => RadioListTile<String>(
              title: Text(e.value),
              value: e.key,
              groupValue: _sortBy,
              activeColor: const Color(0xFF6A11CB),
              onChanged: (v) {
                setState(() {
                  if (_sortBy == v) {
                    _sortDesc = !_sortDesc;
                  } else {
                    _sortBy = v!;
                    _sortDesc = true;
                  }
                });
                Navigator.pop(ctx);
                _loadActivities();
              },
              secondary: Icon(
                _sortBy == e.key
                    ? (_sortDesc
                    ? Icons.arrow_downward
                    : Icons.arrow_upward)
                    : Icons.sort,
                color: _sortBy == e.key
                    ? const Color(0xFF6A11CB)
                    : Colors.grey,
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6A11CB),
        onPressed: () async {
          await _vibrate();
          if (!mounted) return;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AddActivityScreen()),
          );
          if (result == true) _loadActivities();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilter(),
              decoration: InputDecoration(
                hintText: 'Search activities...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),

          // Category Chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
              const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat;
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 3),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    selectedColor: const Color(0xFF6A11CB)
                        .withOpacity(0.15),
                    checkmarkColor: const Color(0xFF6A11CB),
                    labelStyle: TextStyle(
                      color: selected
                          ? const Color(0xFF6A11CB)
                          : null,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (_) async {
                      await _vibrate();
                      setState(
                              () => _selectedCategory = cat);
                      _applyFilter();
                    },
                  ),
                );
              },
            ),
          ),

          // Count + sort indicator
          Padding(
            padding:
            const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filtered.length} activit${_filtered.length == 1 ? 'y' : 'ies'}',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
                Text(
                  'Sorted by ${_sortOptions[_sortBy]} ${_sortDesc ? '↓' : '↑'}',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
              itemCount: _filtered.length,
              padding: const EdgeInsets.only(
                  bottom: 80),
              itemBuilder: (_, i) =>
                  _buildCard(_filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ||
                _selectedCategory != 'All'
                ? 'No results found'
                : 'No activities yet.\nTap + to add one!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Activity activity) {
    final color = _categoryColor(activity.category);
    return Dismissible(
      key: Key('activity_${activity.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete,
            color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        await _vibrate();
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Activity'),
            content:
            Text('Delete "${activity.title}"?'),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        if (activity.id != null) {
          await DatabaseHelper.instance
              .deleteActivity(activity.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🗑️ Activity deleted'),
                backgroundColor: Colors.red,
              ),
            );
          }
          _loadActivities();
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 5),
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await _vibrate();
            if (!mounted) return;
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityDetailScreen(
                    activity: activity),
              ),
            );
            if (result == true) _loadActivities();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail or icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: activity.imagePath != null &&
                      activity.imagePath!.isNotEmpty &&
                      File(activity.imagePath!)
                          .existsSync()
                      ? Image.file(
                    File(activity.imagePath!),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withOpacity(0.7)
                        ],
                      ),
                    ),
                    child: Icon(
                        _categoryIcon(
                            activity.category),
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
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
                      Row(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Text(activity.category,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight:
                                    FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 12,
                              color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text('${activity.hours}h',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(activity.formattedDate,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500])),
                    ],
                  ),
                ),

                // Actions
                Column(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _toggleComplete(activity),
                      child: Icon(
                        activity.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: activity.isCompleted
                            ? Colors.green
                            : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () =>
                          _deleteActivity(activity),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
