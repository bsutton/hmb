class Contact {
  Contact({required this.name});
  final String name;

  Map<String, dynamic> toJson() => {
        'Name': name,
      };
}
