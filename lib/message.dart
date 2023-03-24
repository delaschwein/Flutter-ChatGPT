class Message {
  final String id;
  final String content;
  final String sender;
  final int createdAt;
  final String chatId;
  String messageType;

  Message({
    required this.id,
    required this.content,
    required this.sender,
    required this.createdAt,
    required this.chatId,
    required this.messageType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'sender': sender,
      'createdAt': createdAt,
      'chatId': chatId,
      'messageType': messageType,
    };
  }

  static Message fromMap(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      sender: json['sender'],
      createdAt: json['createdAt'],
      chatId: json['chatId'],
      messageType: json['messageType'],
    );
  }
}
