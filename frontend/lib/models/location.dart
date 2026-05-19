class Location {
  final int userId;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  Location({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      userId: json['user_id'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
