import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/api_services.dart';
import '../helpers/database_helper.dart';
import '../helpers/notification_helper.dart';
import '../helpers/preferences_helper.dart';

class ApiSuggestionsScreen extends StatefulWidget {
  const ApiSuggestionsScreen({super.key});

  @override
  State<ApiSuggestionsScreen> createState() =>
      _ApiSuggestionsScreenState();
}

class _ApiSuggestionsScreenState
    extends State<ApiSuggestionsScreen> {
  List<ActivitySuggestion> _suggestions = [];
  MotivationalQuote? _quote;
  bool _isLoadingSuggestions = false;
  bool _isLoadingQuote = false;
  String _selectedCategory = 'All';
  final Set<int> _savingIndexes = {};
  final Set<String> _savedTitles = {};

  final List<String> _categories = [
    'All', 'Sports', 'Academic', 'Arts',
    'Volunteer', 'Leadership',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadSuggestions(),
      _loadQuote(),
    ]);
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final suggestions =
      await ApiService.fetchMultipleSuggestions(
        count: 6,
        category: _selectedCategory == 'All'
            ? null
            : _selectedCategory,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadSuggestions,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadQuote() async {
    setState(() => _isLoadingQuote = true);
    try {
      final tag = ApiService.quoteTagForCategory(
          _selectedCategory == 'All'
              ? 'motivation'
              : _selectedCategory);
      final quote =
      await ApiService.fetchMotivationalQuote(tag: tag);
      if (mounted) {
        setState(() {
          _quote = quote;
          _isLoadingQuote = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingQuote = false);
    }
  }

  Future<void> _saveActivity(
      ActivitySuggestion suggestion, int index) async {
    setState(() => _savingIndexes.add(index));

    try {
      final activity = suggestion.toActivity();
      await DatabaseHelper.instance.insertActivity(activity);

      // Show notification if enabled
      final notifEnabled = await PreferencesHelper.instance
          .getNotificationsEnabled();
      if (notifEnabled) {
        await NotificationHelper.instance
            .showAchievementNotification(
            '"${activity.title}" added to your log!');
      }

      if (mounted) {
        setState(() => _savedTitles.add(suggestion.title));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('✅ "${suggestion.title}" saved to log!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() => _savingIndexes.remove(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Explorer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh all',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildQuoteCard(),
              const SizedBox(height: 20),
              _buildCategoryFilter(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text('💡 Activity Suggestions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _isLoadingSuggestions
                        ? null
                        : _loadSuggestions,
                    icon: const Icon(Icons.refresh,
                        size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSuggestionsList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2575FC), Color(0xFF6A11CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.explore,
                  color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Activity Explorer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Discover new extracurricular activities. '
                'Powered by live API suggestions with offline fallback.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _headerBadge(Icons.cloud, 'Live API Data'),
              const SizedBox(width: 8),
              _headerBadge(Icons.save_alt,
                  '${_savedTitles.length} Saved'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Quote Card ───────────────────────────────────────────
  Widget _buildQuoteCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade50,
              Colors.orange.shade50
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: _isLoadingQuote
            ? const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                  strokeWidth: 2),
            ))
            : _quote == null
            ? const SizedBox.shrink()
            : Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.format_quote,
                    color:
                    Colors.amber.shade700,
                    size: 20),
                const SizedBox(width: 6),
                Text('Daily Motivation',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.bold,
                        color: Colors
                            .amber.shade800)),
                const Spacer(),
                GestureDetector(
                  onTap: _loadQuote,
                  child: Icon(Icons.refresh,
                      size: 18,
                      color:
                      Colors.amber.shade700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '"${_quote!.content}"',
              style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[800],
                  height: 1.5),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— ${_quote!.author}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                    Colors.amber.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category Filter ──────────────────────────────────────
  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Filter by Category',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = _selectedCategory == cat;
              final color = _categoryColor(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(
                            () => _selectedCategory = cat);
                    _loadAll();
                  },
                  child: AnimatedContainer(
                    duration:
                    const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : color.withOpacity(0.1),
                      borderRadius:
                      BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? color
                              : color.withOpacity(0.3)),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                            color: selected
                                ? Colors.white
                                : color,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Suggestions List ─────────────────────────────────────
  Widget _buildSuggestionsList() {
    if (_isLoadingSuggestions) {
      return Column(
        children: List.generate(
          3,
              (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 130,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2)),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_off,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No suggestions loaded',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Check your internet and tap Refresh',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSuggestions,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _suggestions.asMap().entries.map((entry) {
        return _buildSuggestionCard(
            entry.value, entry.key);
      }).toList(),
    );
  }

  Widget _buildSuggestionCard(
      ActivitySuggestion suggestion, int index) {
    final color =
    _categoryColor(suggestion.mappedCategory);
    final isSaved = _savedTitles.contains(suggestion.title);
    final isSaving = _savingIndexes.contains(index);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSaved
            ? BorderSide(
            color: Colors.green.withOpacity(0.4),
            width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius:
                    BorderRadius.circular(10),
                  ),
                  child: Icon(
                      _categoryIcon(
                          suggestion.mappedCategory),
                      color: color,
                      size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(suggestion.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                          color.withOpacity(0.12),
                          borderRadius:
                          BorderRadius.circular(8),
                        ),
                        child: Text(
                            suggestion.mappedCategory,
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight:
                                FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                if (isSaved)
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 22),
              ],
            ),
            const SizedBox(height: 10),

            // Stats
            Row(
              children: [
                _statChip(
                    Icons.people,
                    '${suggestion.participants} participant(s)',
                    Colors.blue),
                const SizedBox(width: 12),
                _statChip(
                    Icons.speed,
                    suggestion.accessibilityLabel,
                    _difficultyColor(
                        suggestion.accessibilityLabel)),
              ],
            ),
            const SizedBox(height: 12),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaved || isSaving
                    ? null
                    : () =>
                    _saveActivity(suggestion, index),
                icon: isSaving
                    ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : Icon(
                    isSaved
                        ? Icons.check
                        : Icons.save_alt,
                    size: 16),
                label: Text(
                  isSaving
                      ? 'Saving...'
                      : isSaved
                      ? 'Saved to Log ✓'
                      : 'Save to Activity Log',
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSaved
                      ? Colors.green
                      : const Color(0xFF6A11CB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isSaved
                      ? Colors.green.withOpacity(0.6)
                      : Colors.grey,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(
      IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Color _difficultyColor(String label) {
    switch (label) {
      case 'Very Easy':
      case 'Easy':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      default:
        return Colors.red;
    }
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
