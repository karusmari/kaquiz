class User {
  final String name;
  final String email;
  final String? avatar;

  User({required this.name, required this.email, this.avatar});

  factory User.fromJson(Map<String, dynamic> json) => User(
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    avatar: json['avatar'],
  );
}