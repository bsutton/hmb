/// Stable built-in identifiers also used by the migration and singleton index.
class ContactRole {
  static const primary = 1;
  static const billing = 2;
  static const site = 3;
  static const projectManager = 4;
  static const referrer = 5;
  static const owner = 6;
  static const tenant = 7;
  static const bodyCorporateManager = 8;
  static const authoriser = 9;

  final int id;
  final String name;
  final bool builtin;

  const ContactRole({
    required this.id,
    required this.name,
    required this.builtin,
  });

  factory ContactRole.fromMap(Map<String, Object?> map) => ContactRole(
    id: map['id']! as int,
    name: map['name']! as String,
    builtin: map['builtin'] == 1,
  );

  bool get singlePerJob => id == primary || id == billing;
}
