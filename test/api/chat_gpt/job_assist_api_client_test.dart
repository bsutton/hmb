import 'package:hmb/api/chat_gpt/job_assist_api_client.dart';
import 'package:test/test.dart';

void main() {
  test('parses unique additional task suggestions', () {
    final suggestions = parseAdditionalTaskSuggestions('''
      {
        "tasks": [
          {"name": "Replace tap washer", "description": "Kitchen tap."},
          {"name": " replace tap washer ", "description": "Duplicate."},
          {"name": "Repair fence gate", "description": "Adjust latch."}
        ]
      }
    ''');

    expect(suggestions.map((suggestion) => suggestion.name), [
      'Replace tap washer',
      'Repair fence gate',
    ]);
    expect(suggestions.first.description, 'Kitchen tap.');
  });

  test('limits additional task suggestions to six', () {
    final tasks = List.generate(
      8,
      (index) => '{"name":"Task $index"}',
    ).join(',');
    final suggestions = parseAdditionalTaskSuggestions('{"tasks":[$tasks]}');

    expect(suggestions, hasLength(6));
  });

  test('filters duplicate task item suggestions', () {
    final filtered = filterTaskItemAssistSuggestions(
      [
        _suggestion('Paint rollers', 'consumable'),
        _suggestion('Paint rollers', 'consumable'),
        _suggestion('Drop sheets', 'material'),
      ],
      existingDescriptions: ['Drop sheets'],
    );

    expect(filtered.map((item) => item.description), ['Paint rollers']);
  });

  test('filters standard owned tools but keeps hire tools', () {
    final filtered = filterTaskItemAssistSuggestions([
      _suggestion('Cordless drill', 'tool'),
      _suggestion('Access scaffold', 'tool', notes: 'Hire for high wall'),
      _suggestion('Wall paint', 'material'),
    ], existingDescriptions: const []);

    expect(filtered.map((item) => item.description), [
      'Access scaffold',
      'Wall paint',
    ]);
  });
}

TaskItemAssistSuggestion _suggestion(
  String description,
  String category, {
  String notes = '',
}) => TaskItemAssistSuggestion(
  description: description,
  category: category,
  quantity: 1,
  unitCost: 0,
  supplier: '',
  notes: notes,
);
