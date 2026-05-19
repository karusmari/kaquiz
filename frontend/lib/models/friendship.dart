class Friendship {
  final int id;
  final int userId;
  final int friendId;
  final String status; // "pending", "accepted", "rejected"
  final DateTime createdAt;

  Friendship({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      friendId: json['friend_id'] as int,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
