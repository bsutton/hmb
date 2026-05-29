import 'dart:convert';

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

class TaskItemAssistTaskContext {
  final String taskName;
  final String taskDescription;
  final List<String> itemDescriptions;

  const TaskItemAssistTaskContext({
    required this.taskName,
    required this.taskDescription,
    required this.itemDescriptions,
  });
}

class JobAssistApiClient {
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
      tasks: normalizeJobAssistTasks(tasks),
    );
  }

  Future<List<TaskItemAssistSuggestion>?> expandTaskToItems({
    required String jobSummary,
    required String jobDescription,
    required String jobAssumptions,
    required String jobInternalNotes,
    required String taskName,
    required String taskDescription,
    required List<TaskItemAssistTaskContext> existingTasks,
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
                'Suggest only missing estimate items for the named task. '
                'Avoid items already covered by the existing job estimate '
                'context. Keep the list concise, normally 1-5 practical '
                'items. Include likely materials with ballpark unit costs '
                'where reasonable. Do not add common tools a handyman is '
                'expected to own for free. Include a tool only when it is '
                'likely to be hired or bought for this job, and explain why '
                'in notes.',
          },
          {
            'role': 'user',
            'content': _buildTaskItemPrompt(
              jobSummary: jobSummary,
              jobDescription: jobDescription,
              jobAssumptions: jobAssumptions,
              jobInternalNotes: jobInternalNotes,
              taskName: taskName,
              taskDescription: taskDescription,
              existingTasks: existingTasks,
            ),
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

    final suggestions = rawItems
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

    return filterTaskItemAssistSuggestions(
      suggestions,
      existingDescriptions: existingTasks.expand(
        (task) => task.itemDescriptions,
      ),
    );
  }

  String _buildTaskItemPrompt({
    required String jobSummary,
    required String jobDescription,
    required String jobAssumptions,
    required String jobInternalNotes,
    required String taskName,
    required String taskDescription,
    required List<TaskItemAssistTaskContext> existingTasks,
  }) {
    final buffer = StringBuffer()
      ..writeln('Job summary: $jobSummary')
      ..writeln('Job description: $jobDescription');
    if (jobAssumptions.trim().isNotEmpty) {
      buffer.writeln('Job assumptions: $jobAssumptions');
    }
    if (jobInternalNotes.trim().isNotEmpty) {
      buffer.writeln('Internal notes: $jobInternalNotes');
    }
    buffer
      ..writeln('Task to expand: $taskName')
      ..writeln('Task description: $taskDescription')
      ..writeln('Existing job estimate context:');

    for (final task in existingTasks) {
      buffer.writeln('- Task: ${task.taskName}');
      if (task.taskDescription.trim().isNotEmpty) {
        buffer.writeln('  Description: ${task.taskDescription}');
      }
      if (task.itemDescriptions.isEmpty) {
        buffer.writeln('  Items: none');
      } else {
        buffer.writeln('  Items: ${task.itemDescriptions.join('; ')}');
      }
    }
    return buffer.toString();
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

List<TaskItemAssistSuggestion> filterTaskItemAssistSuggestions(
  Iterable<TaskItemAssistSuggestion> suggestions, {
  required Iterable<String> existingDescriptions,
}) {
  final seen = existingDescriptions
      .map(_normalizeTaskItemDescription)
      .where((description) => description.isNotEmpty)
      .toSet();
  final filtered = <TaskItemAssistSuggestion>[];

  for (final suggestion in suggestions) {
    final normalized = _normalizeTaskItemDescription(suggestion.description);
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    if (_isStandardOwnedTool(suggestion)) {
      continue;
    }
    seen.add(normalized);
    filtered.add(suggestion);
  }

  return filtered;
}

String _normalizeTaskItemDescription(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(' +'), ' ');

bool _isStandardOwnedTool(TaskItemAssistSuggestion suggestion) {
  if (suggestion.category.trim().toLowerCase() != 'tool') {
    return false;
  }

  final text = _normalizeTaskItemDescription(
    '${suggestion.description} ${suggestion.notes}',
  );
  if (RegExp(
    r'\b(hire|hired|rental|rent|specialist|scaffold)\b',
  ).hasMatch(text)) {
    return false;
  }

  const standardTools = [
    'drill',
    'hammer',
    'screwdriver',
    'screwdrivers',
    'tape measure',
    'spirit level',
    'level',
    'ladder',
    'saw',
    'pliers',
    'wrench',
    'spanner',
    'utility knife',
    'caulking gun',
    'paint brush',
    'roller',
    'clamps',
  ];

  return standardTools.any(text.contains);
}

List<String> normalizeJobAssistTasks(
  List<String> rawTasks, {
  int maxTasks = 6,
}) {
  final unique = <String>{};
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
