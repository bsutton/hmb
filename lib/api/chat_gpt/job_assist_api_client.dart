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
    final content =
        (choice['message'] as Map<String, dynamic>)['content'] as String;
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
