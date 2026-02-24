class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime sentAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'sentAt': sentAt.toIso8601String(),
    'isRead': isRead,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    text: json['text'],
    sentAt: DateTime.parse(json['sentAt']),
    isRead: json['isRead'] ?? false,
  );

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    DateTime? sentAt,
    bool? isRead,
  }) => Message(
    id: id ?? this.id,
    senderId: senderId ?? this.senderId,
    receiverId: receiverId ?? this.receiverId,
    text: text ?? this.text,
    sentAt: sentAt ?? this.sentAt,
    isRead: isRead ?? this.isRead,
  );
}
