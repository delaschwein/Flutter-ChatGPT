class Chat {
  final String id;
  final int createdAt;
  final String title;

  Chat({
    required this.id,
    required this.createdAt,
    required this.title
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "createdAt": createdAt,
      "title": title,
    };
  }

  static Chat fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map["id"],
      createdAt: map["createdAt"],
      title: map["title"],
    );
  }
}
