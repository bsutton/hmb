class Backup {
  Backup({
    required this.id,
    required this.when,
    required this.pathTo,
    required this.size,
    required this.status,
    required this.error,
  });

  String id;
  DateTime when;
  String pathTo;
  String size;
  String status;
  String error;
}
