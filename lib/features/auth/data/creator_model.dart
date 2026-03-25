class CreatorModel {
  const CreatorModel({
    required this.creatorId,
    required this.name,
    required this.email,
    this.niches = const [],
    this.tiktokConnected = false,
  });

  final String creatorId;
  final String name;
  final String email;
  final List<String> niches;
  final bool tiktokConnected;

  CreatorModel copyWith({
    String? creatorId,
    String? name,
    String? email,
    List<String>? niches,
    bool? tiktokConnected,
  }) {
    return CreatorModel(
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      email: email ?? this.email,
      niches: niches ?? this.niches,
      tiktokConnected: tiktokConnected ?? this.tiktokConnected,
    );
  }
}
