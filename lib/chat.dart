class Chat {
  final String id;
  final int createdAt;
  //final List<Message> messages;

  Chat({
    required this.id,
    required this.createdAt,
    //required this.messages,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt,
      //'messages': messages.map((message) => message.toMap()).toList(),
    };
  }

  static Chat fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'],
      createdAt: map['createdAt'],
      /* messages: List<Message>.from(
        map['messages'].map((message) => Message.fromMap(message)),
      ), */
    );
  }
}
