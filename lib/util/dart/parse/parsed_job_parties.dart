/// Suggestions from source material; none are confirmed job assignments.
class ParsedJobParties {
  final String referringCustomer;
  final String referralEvidence;
  final String billToCustomer;
  final String billingEvidence;
  final List<ParsedJobParty> contacts;

  const ParsedJobParties({
    this.referringCustomer = '',
    this.referralEvidence = '',
    this.billToCustomer = '',
    this.billingEvidence = '',
    this.contacts = const [],
  });

  factory ParsedJobParties.fromJson(Map<String, dynamic> json) =>
      ParsedJobParties(
        referringCustomer: _text(json, 'referringCustomer'),
        referralEvidence: _text(json, 'referralEvidence'),
        billToCustomer: _text(json, 'billToCustomer'),
        billingEvidence: _text(json, 'billingEvidence'),
        contacts: [
          for (final entry in (json['contacts'] as List? ?? []))
            if (entry is Map<String, dynamic>) ParsedJobParty.fromJson(entry),
        ],
      );
}

class ParsedJobParty {
  final String firstName;
  final String surname;
  final String email;
  final String phone;
  final String customerName;
  final String role;
  final String evidence;

  const ParsedJobParty({
    required this.firstName,
    required this.surname,
    required this.email,
    required this.phone,
    required this.customerName,
    required this.role,
    required this.evidence,
  });

  String get name => '$firstName $surname'.trim();

  factory ParsedJobParty.fromJson(Map<String, dynamic> json) => ParsedJobParty(
    firstName: _text(json, 'firstName'),
    surname: _text(json, 'surname'),
    email: _text(json, 'email'),
    phone: _text(json, 'phone'),
    customerName: _text(json, 'customerName'),
    role: _text(json, 'role'),
    evidence: _text(json, 'evidence'),
  );
}

String _text(Map<String, dynamic> json, String key) =>
    (json[key] is String ? json[key] as String : '').trim();
