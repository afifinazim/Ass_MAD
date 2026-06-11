import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/activity.dart';

// ─── Data Models ──────────────────────────────────────────────

class ActivitySuggestion {
  final String title;
  final String type;
  final int participants;
  final double accessibility;
  final String link;
  final String mappedCategory;

  const ActivitySuggestion({
    required this.title,
    required this.type,
    required this.participants,
    required this.accessibility,
    required this.link,
    required this.mappedCategory,
  });

  String get accessibilityLabel {
    final pct = ((1 - accessibility) * 100).toInt();
    if (pct >= 80) return 'Very Easy';
    if (pct >= 60) return 'Easy';
    if (pct >= 40) return 'Moderate';
    if (pct >= 20) return 'Hard';
    return 'Very Hard';
  }

  Activity toActivity() {
    return Activity(
      title: title,
      category: mappedCategory,
      date: DateTime.now(),
      hours: 1,
      description:
      'Suggested activity for $participants participant(s). '
          'Difficulty: $accessibilityLabel.',
      isCompleted: false,
      sourceUrl: link.isNotEmpty ? link : null,
    );
  }
}

class MotivationalQuote {
  final String content;
  final String author;
  final List<String> tags;

  const MotivationalQuote({
    required this.content,
    required this.author,
    required this.tags,
  });

  /// Built-in fallback quotes — always available offline
  static final List<MotivationalQuote> fallbackQuotes = [
    const MotivationalQuote(
      content: 'The secret of getting ahead is getting started.',
      author: 'Mark Twain',
      tags: ['motivation'],
    ),
    const MotivationalQuote(
      content:
      'It does not matter how slowly you go as long as you do not stop.',
      author: 'Confucius',
      tags: ['perseverance'],
    ),
    const MotivationalQuote(
      content:
      'Success is the sum of small efforts, repeated day in and day out.',
      author: 'Robert Collier',
      tags: ['success'],
    ),
    const MotivationalQuote(
      content: "Believe you can and you're halfway there.",
      author: 'Theodore Roosevelt',
      tags: ['belief'],
    ),
    const MotivationalQuote(
      content: 'The only way to do great work is to love what you do.',
      author: 'Steve Jobs',
      tags: ['work'],
    ),
    const MotivationalQuote(
      content: 'In the middle of every difficulty lies opportunity.',
      author: 'Albert Einstein',
      tags: ['motivation'],
    ),
    const MotivationalQuote(
      content: "Don't watch the clock; do what it does. Keep going.",
      author: 'Sam Levenson',
      tags: ['perseverance'],
    ),
    const MotivationalQuote(
      content: "It always seems impossible until it's done.",
      author: 'Nelson Mandela',
      tags: ['motivation'],
    ),
    const MotivationalQuote(
      content:
      'Energy and persistence conquer all things.',
      author: 'Benjamin Franklin',
      tags: ['perseverance'],
    ),
    const MotivationalQuote(
      content: 'Talent wins games, but teamwork and intelligence win championships.',
      author: 'Michael Jordan',
      tags: ['sports', 'teamwork'],
    ),
  ];
}

// ─── Built-in Fallback Activities ─────────────────────────────
// Used when API is unavailable (offline / rate-limited)

const List<Map<String, dynamic>> _builtInActivities = [
  {
    'title': 'Join a Debate Club',
    'category': 'Academic',
    'participants': 10,
    'accessibility': 0.3,
    'link': '',
  },
  {
    'title': 'Volunteer at Animal Shelter',
    'category': 'Volunteer',
    'participants': 3,
    'accessibility': 0.2,
    'link': '',
  },
  {
    'title': 'Learn Watercolour Painting',
    'category': 'Arts',
    'participants': 1,
    'accessibility': 0.4,
    'link': '',
  },
  {
    'title': 'Join Basketball Intramural',
    'category': 'Sports',
    'participants': 10,
    'accessibility': 0.3,
    'link': '',
  },
  {
    'title': 'Student Council Campaign',
    'category': 'Leadership',
    'participants': 5,
    'accessibility': 0.5,
    'link': '',
  },
  {
    'title': 'Chess Tournament',
    'category': 'Academic',
    'participants': 2,
    'accessibility': 0.4,
    'link': '',
  },
  {
    'title': 'Community Clean-Up Drive',
    'category': 'Volunteer',
    'participants': 8,
    'accessibility': 0.2,
    'link': '',
  },
  {
    'title': 'Photography Workshop',
    'category': 'Arts',
    'participants': 1,
    'accessibility': 0.4,
    'link': '',
  },
  {
    'title': 'Futsal Tournament',
    'category': 'Sports',
    'participants': 10,
    'accessibility': 0.3,
    'link': '',
  },
  {
    'title': 'Science Fair Project',
    'category': 'Academic',
    'participants': 3,
    'accessibility': 0.5,
    'link': '',
  },
  {
    'title': 'Mentor a Junior Student',
    'category': 'Leadership',
    'participants': 2,
    'accessibility': 0.2,
    'link': '',
  },
  {
    'title': 'Traditional Dance Practice',
    'category': 'Arts',
    'participants': 6,
    'accessibility': 0.4,
    'link': '',
  },
  {
    'title': 'Recycling Awareness Campaign',
    'category': 'Volunteer',
    'participants': 5,
    'accessibility': 0.2,
    'link': '',
  },
  {
    'title': 'Badminton Club',
    'category': 'Sports',
    'participants': 4,
    'accessibility': 0.3,
    'link': '',
  },
  {
    'title': 'Public Speaking Contest',
    'category': 'Leadership',
    'participants': 1,
    'accessibility': 0.6,
    'link': '',
  },
  {
    'title': 'Library Reading Programme',
    'category': 'Academic',
    'participants': 1,
    'accessibility': 0.1,
    'link': '',
  },
  {
    'title': 'Food Bank Volunteering',
    'category': 'Volunteer',
    'participants': 4,
    'accessibility': 0.2,
    'link': '',
  },
  {
    'title': 'Drama Club Rehearsal',
    'category': 'Arts',
    'participants': 12,
    'accessibility': 0.5,
    'link': '',
  },
];

// ─── API Ninjas Activity Type → App Category map ──────────────

/// Maps API Ninjas activity types to your app's 5 categories.
/// API Ninjas types: education, recreational, social, diy, charity,
/// cooking, relaxation, music, busywork
const Map<String, String> _typeToCategory = {
  'education': 'Academic',
  'recreational': 'Sports',
  'social': 'Leadership',
  'diy': 'Arts',
  'charity': 'Volunteer',
  'cooking': 'Arts',
  'relaxation': 'Sports',
  'music': 'Arts',
  'busywork': 'Leadership',
};

/// Maps your app category back to an API Ninjas type for filtered fetches.
const Map<String, String> _categoryToType = {
  'Academic': 'education',
  'Sports': 'recreational',
  'Arts': 'music',
  'Volunteer': 'charity',
  'Leadership': 'social',
};

// ─── API Service ──────────────────────────────────────────────

class ApiService {
  // ── API Ninjas key & endpoint ─────────────────────────────
  static const _apiKey = 'ci6YKYc0KLw9jl6yXt17Id4Apw4gJWMsvZGi1dW3';
  static const _baseUrl = 'https://api.api-ninjas.com/v1/activity';

  // ── Quotable.io for motivational quotes ───────────────────
  static const _quoteUrl = 'https://api.quotable.io/random';

  static const _timeout = Duration(seconds: 10);

  // ─── Fetch Multiple Suggestions ───────────────────────────
  /// Fetches [count] activity suggestions from API Ninjas.
  /// If [category] is provided, filters by that app category.
  /// Falls back to built-in list on any error.
  static Future<List<ActivitySuggestion>> fetchMultipleSuggestions({
    int count = 6,
    String? category,
  }) async {
    // Skip network on web (CORS) — use built-in immediately
    if (kIsWeb) {
      return _getBuiltInSuggestions(category: category, count: count);
    }

    try {
      final results = await _fetchFromApiNinjas(
        count: count,
        category: category,
      );
      if (results.isNotEmpty) return results;
    } on ApiException {
      rethrow; // propagate meaningful errors to UI
    } catch (_) {}

    // Always-available built-in fallback
    return _getBuiltInSuggestions(category: category, count: count);
  }

  // ─── Fetch Single by Category (used in AddActivityScreen) ─
  static Future<ActivitySuggestion> fetchActivityByCategory(
      String category) async {
    final list = await fetchMultipleSuggestions(
      count: 1,
      category: category,
    );
    return list.first;
  }

  // ─── Core API Ninjas fetch ─────────────────────────────────
  static Future<List<ActivitySuggestion>> _fetchFromApiNinjas({
    required int count,
    String? category,
  }) async {
    final List<ActivitySuggestion> results = [];

    // Determine the type param to send (null = random)
    final String? typeParam =
    (category != null && category != 'All')
        ? _categoryToType[category]
        : null;

    // API Ninjas returns 1 activity per call, so we call [count] times.
    // We run up to count+2 attempts to handle occasional duplicates.
    final Set<String> seen = {};
    int attempts = 0;
    final maxAttempts = count + 3;

    while (results.length < count && attempts < maxAttempts) {
      attempts++;
      try {
        final uri = Uri.parse(_baseUrl).replace(
          queryParameters: {
            if (typeParam != null) 'type': typeParam,
          },
        );

        final response = await http.get(
          uri,
          headers: {'X-Api-Key': _apiKey},
        ).timeout(_timeout);

        if (response.statusCode == 401) {
          throw const ApiException(
              'Invalid API key. Please check your API Ninjas key.');
        }
        if (response.statusCode == 429) {
          throw const ApiException(
              'API rate limit reached. Please try again shortly.');
        }
        if (response.statusCode != 200) {
          throw ApiException(
              'API error: ${response.statusCode}');
        }

        final data = jsonDecode(response.body);

        // API Ninjas returns a single object (not a list)
        final String title =
        (data['activity'] as String? ?? '').trim();
        if (title.isEmpty || seen.contains(title)) continue;
        seen.add(title);

        final String rawType =
        (data['type'] as String? ?? 'recreational')
            .toLowerCase();
        final int participants =
            (data['participants'] as int?) ?? 1;
        final double accessibility =
        (data['accessibility'] is double)
            ? data['accessibility'] as double
            : (data['accessibility'] as num).toDouble();
        final String link =
        (data['link'] as String? ?? '').trim();

        // Map to app category
        String mappedCategory =
            _typeToCategory[rawType] ?? 'Other';
        // If a category filter was requested, honour it
        if (category != null &&
            category != 'All' &&
            category.isNotEmpty) {
          mappedCategory = category;
        }

        results.add(ActivitySuggestion(
          title: _truncateTitle(title),
          type: rawType,
          participants: participants,
          accessibility: accessibility.clamp(0.0, 1.0),
          link: link,
          mappedCategory: mappedCategory,
        ));
      } on ApiException {
        rethrow;
      } catch (_) {
        // Network / parse error on a single call → skip & retry
      }
    }

    if (results.isEmpty) {
      throw const ApiException(
          'Could not load suggestions. Check your internet connection.');
    }

    return results;
  }

  // ─── Built-in Fallback ────────────────────────────────────
  static List<ActivitySuggestion> _getBuiltInSuggestions({
    String? category,
    int count = 6,
  }) {
    var list =
    List<Map<String, dynamic>>.from(_builtInActivities);

    if (category != null && category != 'All') {
      list = list
          .where((a) => a['category'] == category)
          .toList();
    }

    list.shuffle(Random());
    return list.take(count).map((a) {
      return ActivitySuggestion(
        title: a['title'] as String,
        type: 'other',
        participants: a['participants'] as int,
        accessibility: a['accessibility'] as double,
        link: a['link'] as String,
        mappedCategory: a['category'] as String,
      );
    }).toList();
  }

  // ─── Motivational Quote ───────────────────────────────────
  /// Fetches from Quotable.io with a tag hint.
  /// Falls back to built-in quotes if unavailable.
  static Future<MotivationalQuote> fetchMotivationalQuote({
    String? tag,
  }) async {
    if (!kIsWeb) {
      try {
        final queryParams = <String, String>{
          'maxLength': '150',
          if (tag != null) 'tags': tag,
        };
        final uri = Uri.parse(_quoteUrl)
            .replace(queryParameters: queryParams);

        final response =
        await http.get(uri).timeout(_timeout);

        if (response.statusCode == 200) {
          final json =
          jsonDecode(response.body) as Map<String, dynamic>;
          final content =
          (json['content'] as String? ?? '').trim();
          if (content.isNotEmpty) {
            return MotivationalQuote(
              content: content,
              author: json['author'] as String? ?? 'Unknown',
              tags: List<String>.from(
                  json['tags'] as List? ?? []),
            );
          }
        }
      } catch (_) {}
    }

    return _fallbackQuote();
  }

  static MotivationalQuote _fallbackQuote() {
    final quotes =
    List<MotivationalQuote>.from(
        MotivationalQuote.fallbackQuotes)
      ..shuffle(Random());
    return quotes.first;
  }

  /// Returns a Quotable tag appropriate for the given category.
  static String quoteTagForCategory(String category) {
    switch (category) {
      case 'Sports':
        return 'sports';
      case 'Academic':
        return 'education';
      case 'Arts':
        return 'creativity';
      case 'Volunteer':
        return 'kindness';
      case 'Leadership':
        return 'leadership';
      default:
        return 'motivation';
    }
  }

  // ─── Helpers ──────────────────────────────────────────────
  static String _truncateTitle(String text) {
    text = text.trim();
    if (text.length > 60) {
      return '${text.substring(0, 57)}...';
    }
    return text;
  }
}

// ─── Custom Exception ─────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
