import 'dart:convert';
import 'dart:collection';

import 'package:http/http.dart' as http;

import '../../dao/dao_system.dart';

class JobAssistResult {
  final String summary;
  final String description;
  final List<String> tasks;

  JobAssistResult({
    required this.summary,
    required this.description,
    required this.tasks,
  });
}

class TaskItemAssistSuggestion {
  final String description;
  final String category;
  final double quantity;
  final double unitCost;
  final String supplier;
  final String notes;

  TaskItemAssistSuggestion({
    required this.description,
    required this.category,
    required this.quantity,
    required this.unitCost,
    required this.supplier,
    required this.notes,
  });
}

class JobAssistApiClient {
  static const _maxTasks = 6;

  Future<JobAssistResult?> analyzeDescription(String description) async {
    final system = await DaoSystem().get();
    final apiKey = system.openaiApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'system',
            'content':
                'You help a handyman app. Return JSON only with keys: '
                'summary (short job title, <= 60 chars), description '
                '(short clear job description, <= 280 chars), and tasks '
                '(array of short task titles). Use high-level, billable '
                'task outcomes only. Do not break a single activity into '
                'step-by-step subtasks. Prefer 3-6 tasks total.',
          },
          {'role': 'user', 'content': description},
        ],
        'temperature': 0.2,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode}: ${response.body}',
      );
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    final choice =
        (jsonResponse['choices'] as List).first as Map<String, dynamic>;
    final content = _normalizeContent(
      (choice['message'] as Map<String, dynamic>)['content'] as String,
    );
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final summary = (parsed['summary'] as String?)?.trim() ?? '';
    final extractedDescription =
        (parsed['description'] as String?)?.trim() ?? '';
    final tasks = (parsed['tasks'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return JobAssistResult(
      summary: summary,
      description: extractedDescription,
      tasks: normalizeJobAssistTasks(tasks, maxTasks: _maxTasks),
    );
  }

  Future<List<TaskItemAssistSuggestion>?> expandTaskToItems({
    required String jobSummary,
    required String jobDescription,
    required String taskName,
    required String taskDescription,
  }) async {
    final system = await DaoSystem().get();
    final apiKey = system.openaiApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content':
                'You help a handyman estimator. Return JSON only with key '
                '"items" which is an array. Each item must have: description '
                '(string), category (one of labour|material|tool|consumable), '
                'quantity (number), unitCost (number in AUD, 0 if unknown), '
                'supplier (string, empty if unknown), notes (string). '
                'Prefer 3-8 practical items and include likely materials with '
                'ballpark unit costs where reasonable.',
          },
          {
            'role': 'user',
            'content':
                'Job summary: $jobSummary\n'
                'Job description: $jobDescription\n'
                'Task: $taskName\n'
                'Task description: $taskDescription',
          },
        ],
        'temperature': 0.2,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode}: ${response.body}',
      );
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    final choice =
        (jsonResponse['choices'] as List).first as Map<String, dynamic>;
    final content = _normalizeContent(
      (choice['message'] as Map<String, dynamic>)['content'] as String,
    );
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final rawItems = parsed['items'] as List<dynamic>? ?? const [];

    return rawItems
        .map((item) {
          final map = item as Map<String, dynamic>;
          return TaskItemAssistSuggestion(
            description: (map['description'] as String? ?? '').trim(),
            category: (map['category'] as String? ?? 'material').trim(),
            quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
            unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
            supplier: (map['supplier'] as String? ?? '').trim(),
            notes: (map['notes'] as String? ?? '').trim(),
          );
        })
        .where((item) => item.description.isNotEmpty)
        .toList();
  }

  String _normalizeContent(String content) {
    var trimmed = content.trim();
    if (trimmed.startsWith('```')) {
      final lines = trimmed.split('\n').toList();
      if (lines.isNotEmpty && lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
        lines.removeLast();
      }
      trimmed = lines.join('\n').trim();
    }
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        trimmed = jsonDecode(trimmed) as String;
      } catch (_) {
        // fall through
      }
    }
    return trimmed;
  }
}

List<String> normalizeJobAssistTasks(
  List<String> rawTasks, {
  int maxTasks = 6,
}) {
  final unique = LinkedHashSet<String>();
  for (final raw in rawTasks) {
    final task = raw.trim();
    if (task.isEmpty) {
      continue;
    }
    final normalizedKey = task.toLowerCase();
    if (unique.any((e) => e.toLowerCase() == normalizedKey)) {
      continue;
    }
    unique.add(task);
    if (unique.length >= maxTasks) {
      break;
    }
  }
  return unique.toList();
}
