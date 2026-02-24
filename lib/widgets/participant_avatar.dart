import 'dart:math';
import 'package:flutter/material.dart';
import 'package:panda_dating_app/models/live_participant.dart';
import 'package:panda_dating_app/theme.dart';

class ParticipantAvatar extends StatefulWidget {
  final LiveParticipant participant;
  final bool showWave;
  final VoidCallback? onTap;
  const ParticipantAvatar({super.key, required this.participant, this.showWave = false, this.onTap});

  @override
  State<ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<ParticipantAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.participant;
    final initials = p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?';
    final color = p.isHost ? PandaColors.peachDark : PandaColors.purple;
    final bg = p.isSpeaker ? PandaColors.bgCardHover : PandaColors.bgCard;
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (widget.showWave && !p.isMuted)
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final t = _c.value;
                    return Container(
                      width: 56 + sin(t * pi) * 6,
                      height: 56 + sin(t * pi) * 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.15),
                      ),
                    );
                  },
                ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              if (p.isMuted)
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: CircleAvatar(radius: 10, backgroundColor: Colors.black, child: Icon(Icons.mic_off, color: Colors.white, size: 12)),
                )
              else
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: CircleAvatar(radius: 10, backgroundColor: Colors.black, child: Icon(Icons.mic, color: Colors.white, size: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(
              p.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12),
            ),
          )
        ],
      ),
    );
  }
}
