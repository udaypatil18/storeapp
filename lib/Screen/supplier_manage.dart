class Dealer {
  final int id;
  final String name;
  final String phoneNumber;
  final String location;
  final List<String> specialties;

  Dealer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.location,
    this.specialties = const [],
  });
}
