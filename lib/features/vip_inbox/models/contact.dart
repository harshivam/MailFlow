class Contact {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isVip;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.isVip = false,
  });

  Contact copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    bool? isVip,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isVip: isVip ?? this.isVip,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isVip': isVip,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      photoUrl: json['photoUrl'],
      isVip: json['isVip'] ?? false,
    );
  }
}
