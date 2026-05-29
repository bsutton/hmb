import 'package:hmb/api/chat_gpt/job_assist_api_client.dart';
import 'package:test/test.dart';

void main() {
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
