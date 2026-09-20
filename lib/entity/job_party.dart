import 'contact.dart';
import 'contact_role.dart';

class JobParty {
  final int id;
  final Contact contact;
  final ContactRole role;

  const JobParty({required this.id, required this.contact, required this.role});
}
