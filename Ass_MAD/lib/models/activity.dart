class Activity {
  int? id;
  final String title;
  final String category;
  final DateTime date;
  final int hours;
  final String description;
  bool isCompleted;
  String? imagePath;  // Gallery photo path
  String? sourceUrl;  // From API suggestion
  int? steps;         // Pedometer steps logged

  Activity({
    this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.hours,
    required this.description,
    required this.isCompleted,
    this.imagePath,
    this.sourceUrl,
    this.steps,
  });

  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'date': date.toIso8601String(),
      'hours': hours,
      'description': description,
      'isCompleted': isCompleted ? 1 : 0,
      'imagePath': imagePath,
      'sourceUrl': sourceUrl,
      'steps': steps,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'],
      title: map['title'],
      category: map['category'],
      date: DateTime.parse(map['date']),
      hours: map['hours'],
      description: map['description'],
      isCompleted: map['isCompleted'] == 1,
      imagePath: map['imagePath'],
      sourceUrl: map['sourceUrl'],
      steps: map['steps'],
    );
  }

  // ─── API Ninjas factory ───────────────────────────────────
  /// Creates an Activity from a raw API Ninjas /v1/activity response.
  /// This is used internally by ActivitySuggestion.toActivity() but
  /// can also be called directly if you have the raw JSON map.
  factory Activity.fromApiNinjas(Map<String, dynamic> json) {
    final String title =
    (json['activity'] as String? ?? 'New Activity').trim();
    final String rawType =
    (json['type'] as String? ?? 'recreational').toLowerCase();
    final int participants = (json['participants'] as int?) ?? 1;
    final double accessibility =
    (json['accessibility'] is double)
        ? json['accessibility'] as double
        : ((json['accessibility'] as num?)?.toDouble() ?? 0.5);
    final String link = (json['link'] as String? ?? '').trim();

    // Difficulty label based on accessibility score (0 = easy, 1 = hard)
    final int diffPct = ((1 - accessibility.clamp(0.0, 1.0)) * 100).toInt();
    final String diffLabel = diffPct >= 80
        ? 'Very Easy'
        : diffPct >= 60
        ? 'Easy'
        : diffPct >= 40
        ? 'Moderate'
        : diffPct >= 20
        ? 'Hard'
        : 'Very Hard';

    return Activity(
      title: title.length > 60
          ? '${title.substring(0, 57)}...'
          : title,
      category: _mapApiNinjasType(rawType),
      date: DateTime.now(),
      hours: 1,
      description:
      'Suggested activity for $participants participant(s). '
          'Difficulty: $diffLabel.',
      isCompleted: false,
      sourceUrl: link.isNotEmpty ? link : null,
    );
  }

  /// Maps API Ninjas activity types to app categories.
  static String _mapApiNinjasType(String type) {
    switch (type) {
      case 'education':
        return 'Academic';
      case 'recreational':
      case 'relaxation':
        return 'Sports';
      case 'social':
      case 'busywork':
        return 'Leadership';
      case 'diy':
      case 'cooking':
      case 'music':
        return 'Arts';
      case 'charity':
        return 'Volunteer';
      default:
        return 'Other';
    }
  }

  // ─── copyWith ─────────────────────────────────────────────
  Activity copyWith({
    int? id,
    String? title,
    String? category,
    DateTime? date,
    int? hours,
    String? description,
    bool? isCompleted,
    String? imagePath,
    String? sourceUrl,
    int? steps,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      date: date ?? this.date,
      hours: hours ?? this.hours,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      imagePath: imagePath ?? this.imagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      steps: steps ?? this.steps,
    );
  }
}
