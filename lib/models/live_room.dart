import 'package:panda_dating_app/models/live_participant.dart';

enum LiveRoomType { audio, video }

class LiveRoom {
  final String id;
  final String title;
  final String topic;
  final LiveRoomType type;
  final bool isLive;
  final bool isRecording;
  final String hostId;
  final List<LiveParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveRoom({
    required this.id,
    required this.title,
    required this.topic,
    required this.type,
    required this.isLive,
    required this.isRecording,
    required this.hostId,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
  });

  LiveRoom copyWith({
    String? id,
    String? title,
    String? topic,
    LiveRoomType? type,
    bool? isLive,
    bool? isRecording,
    String? hostId,
    List<LiveParticipant>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LiveRoom(
        id: id ?? this.id,
        title: title ?? this.title,
        topic: topic ?? this.topic,
        type: type ?? this.type,
        isLive: isLive ?? this.isLive,
        isRecording: isRecording ?? this.isRecording,
        hostId: hostId ?? this.hostId,
        participants: participants ?? this.participants,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'topic': topic,
        'type': type.name,
        'isLive': isLive,
        'isRecording': isRecording,
        'hostId': hostId,
        'participants': participants.map((p) => p.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LiveRoom.fromJson(Map<String, dynamic> json) => LiveRoom(
        id: json['id'],
        title: json['title'],
        topic: json['topic'],
        type: (json['type'] as String) == 'video' ? LiveRoomType.video : LiveRoomType.audio,
        isLive: json['isLive'] ?? false,
        isRecording: json['isRecording'] ?? false,
        hostId: json['hostId'],
        participants: (json['participants'] as List?)
                ?.map((e) => LiveParticipant.fromJson(e))
                .toList() ??
            const [],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}
