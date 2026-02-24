import 'package:flutter/foundation.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String type; // e.g., speed_dating, mixer, virtual
  final String format; // online, in_person, hybrid
  final int capacity;
  final int rsvpCount;
  final List<String> tags;
  final String bannerEmoji; // simple visual
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.type,
    required this.format,
    required this.capacity,
    required this.rsvpCount,
    required this.tags,
    required this.bannerEmoji,
    required this.createdAt,
    required this.updatedAt,
  });

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? type,
    String? format,
    int? capacity,
    int? rsvpCount,
    List<String>? tags,
    String? bannerEmoji,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EventModel(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        location: location ?? this.location,
        type: type ?? this.type,
        format: format ?? this.format,
        capacity: capacity ?? this.capacity,
        rsvpCount: rsvpCount ?? this.rsvpCount,
        tags: tags ?? this.tags,
        bannerEmoji: bannerEmoji ?? this.bannerEmoji,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'location': location,
        'type': type,
        'format': format,
        'capacity': capacity,
        'rsvpCount': rsvpCount,
        'tags': tags,
        'bannerEmoji': bannerEmoji,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        location: json['location'],
        type: json['type'],
        format: json['format'],
        capacity: json['capacity'],
        rsvpCount: json['rsvpCount'],
        tags: List<String>.from(json['tags'] ?? const []),
        bannerEmoji: json['bannerEmoji'] ?? '🎉',
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}
