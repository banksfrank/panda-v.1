import 'package:flutter/material.dart';
import 'package:panda_dating_app/models/live_room.dart';
import 'package:panda_dating_app/theme.dart';

class RoomCard extends StatelessWidget {
  final LiveRoom room;
  final VoidCallback onJoin;
  const RoomCard({super.key, required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final speakers = room.participants.where((p) => p.isSpeaker).length;
    final listeners = room.participants.length - speakers;
    final typeColor = room.type == LiveRoomType.audio ? PandaColors.purple : PandaColors.peachDark;
    final typeIcon = room.type == LiveRoomType.audio ? Icons.graphic_eq : Icons.videocam;
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PandaColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(room.title, style: const TextStyle(color: PandaColors.textPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        if (room.isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: PandaColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: Row(children: const [
                              Icon(Icons.circle, size: 8, color: PandaColors.danger),
                              SizedBox(width: 4),
                              Text('LIVE', style: TextStyle(color: PandaColors.danger, fontSize: 10, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(room.topic, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _JoinButton(onJoin: onJoin),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.mic, size: 14, color: PandaColors.textMuted),
              const SizedBox(width: 4),
              Text('$speakers speakers', style: const TextStyle(color: PandaColors.textMuted, fontSize: 12)),
              const SizedBox(width: 12),
              Icon(Icons.headset, size: 14, color: PandaColors.textMuted),
              const SizedBox(width: 4),
              Text('$listeners listeners', style: const TextStyle(color: PandaColors.textMuted, fontSize: 12)),
              const Spacer(),
              if (room.isRecording)
                Row(children: const [
                  Icon(Icons.fiber_smart_record, size: 14, color: Colors.redAccent),
                  SizedBox(width: 4),
                  Text('REC', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
            ]),
          ],
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final VoidCallback onJoin;
  const _JoinButton({required this.onJoin});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: PandaColors.gradientButton,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 12)],
        ),
        child: Row(children: const [
          Icon(Icons.play_arrow, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
