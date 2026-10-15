class UserModel {
  final int id;
  final String username;
  final String password;
  final String name;
  final String role; // 'admin' only

  const UserModel({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    this.role = 'admin',
  });

  bool get isAdmin => true;
  bool get isLender => false;
  bool get isViewer => false;

  UserModel copyWith({
    int? id,
    String? username,
    String? password,
    String? name,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'admin',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'name': name,
      'role': role,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      if (id > 0) 'id': id,
      'username': username,
      'password': password,
      'name': name,
      'role': role,
    };
  }
}
