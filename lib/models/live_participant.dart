class LiveParticipant {
  final String id;
  final String displayName;
  final bool isHost;
  final bool isSpeaker;
  final bool isMuted;
  final bool handRaised;
  final bool cameraOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LiveParticipant({
    required this.id,
    required this.displayName,
    this.isHost = false,
    this.isSpeaker = false,
    this.isMuted = true,
    this.handRaised = false,
    this.cameraOn = false,
    required this.createdAt,
    required this.updatedAt,
  });

  LiveParticipant copyWith({
    String? id,
    String? displayName,
    bool? isHost,
    bool? isSpeaker,
    bool? isMuted,
    bool? handRaised,
    bool? cameraOn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LiveParticipant(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        isHost: isHost ?? this.isHost,
        isSpeaker: isSpeaker ?? this.isSpeaker,
        isMuted: isMuted ?? this.isMuted,
        handRaised: handRaised ?? this.handRaised,
        cameraOn: cameraOn ?? this.cameraOn,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'isHost': isHost,
        'isSpeaker': isSpeaker,
        'isMuted': isMuted,
        'handRaised': handRaised,
        'cameraOn': cameraOn,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LiveParticipant.fromJson(Map<String, dynamic> json) => LiveParticipant(
        id: json['id'],
        displayName: json['displayName'],
        isHost: json['isHost'] ?? false,
        isSpeaker: json['isSpeaker'] ?? false,
        isMuted: json['isMuted'] ?? true,
        handRaised: json['handRaised'] ?? false,
        cameraOn: json['cameraOn'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}
