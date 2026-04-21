class User {
  final int id;
  final String email;
  final String username;

  User({required this.id, required this.email, required this.username});

  factory User.fromJson(Map<String, dynamic> json) {
    // Support a few possible shapes: {id, email, username} or {pk, email, username}
    final dynamic rawId = json['id'] ?? json['pk'];
    int parsedId = 0;
    if (rawId is int) parsedId = rawId;
    else if (rawId is String) parsedId = int.tryParse(rawId) ?? 0;

    final email = (json['email'] ?? '') as String;
    final username = (json['username'] ?? '') as String;

    return User(
      id: parsedId,
      email: email,
      username: username,
    );
  }
}
