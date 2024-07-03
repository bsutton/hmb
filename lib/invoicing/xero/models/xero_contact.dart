class XeroContact {
  XeroContact({required this.name});
  final String name;

  Map<String, dynamic> toJson() => {
        'Name': name,
      };
}
