import 'package:panda_dating_app/models/user.dart';

class Match {
  final String id;
  final User user;
  final DateTime matchedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isRead;

  Match({
    required this.id,
    required this.user,
    required this.matchedAt,
    this.lastMessage,
    this.lastMessageTime,
    this.isRead = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user.toJson(),
    'matchedAt': matchedAt.toIso8601String(),
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime?.toIso8601String(),
    'isRead': isRead,
  };

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: json['id'],
    user: User.fromJson(json['user']),
    matchedAt: DateTime.parse(json['matchedAt']),
    lastMessage: json['lastMessage'],
    lastMessageTime: json['lastMessageTime'] != null ? DateTime.parse(json['lastMessageTime']) : null,
    isRead: json['isRead'] ?? true,
  );

  Match copyWith({
    String? id,
    User? user,
    DateTime? matchedAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isRead,
  }) => Match(
    id: id ?? this.id,
    user: user ?? this.user,
    matchedAt: matchedAt ?? this.matchedAt,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    isRead: isRead ?? this.isRead,
  );
}
