import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/models/live_room.dart';
import 'package:panda_dating_app/models/live_participant.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/services/live_room_service.dart';
import 'package:panda_dating_app/widgets/participant_avatar.dart';
import 'package:panda_dating_app/theme.dart';

class LiveRoomScreen extends StatefulWidget {
final String roomId;
const LiveRoomScreen({super.key, required this.roomId});

@override
State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
@override
void initState() {
super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) async {
final auth = context.read<AuthService>();
final userName = auth.currentUser?.name ?? 'You';
await context.read<LiveRoomService>().joinRoom(widget.roomId, userName: userName);
});
}

@override
void dispose() {
context.read<LiveRoomService>().leaveActiveRoom();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: PandaColors.bgPrimary,
appBar: AppBar(
backgroundColor: PandaColors.bgCard,
leading: IconButton(
icon: const Icon(Icons.arrow_back, color: Colors.white),
onPressed: () => context.pop(),
),
title: Consumer<LiveRoomService>(builder: (context, svc, _) {
final room = svc.activeRoom;
if (room == null) return const SizedBox.shrink();
return Row(children: [
Text(room.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
const SizedBox(width: 8),
if (room.isLive)
Container(
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
decoration: BoxDecoration(color: const Color(0xFFFF1744).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppRadius.full)),
child: Row(children: const [Icon(Icons.circle, size: 8, color: Color(0xFFFF1744)), SizedBox(width: 4), Text('LIVE', style: TextStyle(color: Color(0xFFFF1744), fontSize: 10, fontWeight: FontWeight.w800))]),
),
]);
}),
actions: [
Consumer<LiveRoomService>(builder: (context, svc, _) {
final rec = svc.activeRoom?.isRecording ?? false;
return IconButton(
tooltip: rec ? 'Stop recording' : 'Start recording',
onPressed: () => svc.toggleRecording(),
icon: Icon(rec ? Icons.stop_circle : Icons.fiber_manual_record, color: rec ? Colors.redAccent : Colors.white),
);
}),
],
),
body: Consumer<LiveRoomService>(builder: (context, svc, _) {
final room = svc.activeRoom;
if (room == null) {
return const Center(child: CircularProgressIndicator(color: PandaColors.pink));
}
final speakers = room.participants.where((p) => p.isSpeaker).toList();
final listeners = room.participants.where((p) => !p.isSpeaker).toList();
final myId = svc.myParticipantId ?? '';
final me = room.participants.firstWhere((p) => p.id == myId, orElse: () => room.participants.isNotEmpty ? room.participants.first : LiveParticipant(id: myId.isEmpty ? 'me' : myId, displayName: 'You', isMuted: true, createdAt: DateTime.now(), updatedAt: DateTime.now()));

return Column(children: [
// Stage
Expanded(
child: Padding(
padding: const EdgeInsets.all(16),
child: LayoutBuilder(builder: (context, c) {
final isVideo = room.type == LiveRoomType.video;
final cross = c.maxWidth > 900 ? 4 : 3;
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(children: [
const Icon(Icons.mic, color: PandaColors.textMuted, size: 16),
const SizedBox(width: 6),
Text('Speakers • ${speakers.length}', style: const TextStyle(color: PandaColors.textMuted)),
]),
const SizedBox(height: 8),
Expanded(
child: GridView.builder(
gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: isVideo ? 4 / 5 : 1),
itemCount: speakers.length,
itemBuilder: (_, i) => _SpeakerTile(participant: speakers[i], isVideo: isVideo, onLongPress: () => _openUserActions(context, speakers[i], isHost: me.isHost)),
),
),
const SizedBox(height: 12),
Row(children: [
const Icon(Icons.headset, color: PandaColors.textMuted, size: 16),
const SizedBox(width: 6),
Text('Listeners • ${listeners.length}', style: const TextStyle(color: PandaColors.textMuted)),
]),
const SizedBox(height: 8),
SizedBox(
height: 86,
child: ListView.separated(
scrollDirection: Axis.horizontal,
itemBuilder: (_, i) => ParticipantAvatar(participant: listeners[i], onTap: () => _openUserActions(context, listeners[i], isHost: me.isHost)),
separatorBuilder: (_, __) => const SizedBox(width: 12),
itemCount: listeners.length,
),
)
],
);
}),
),
),
_BottomControls(me: me),
]);
}),
);
}

void _openUserActions(BuildContext context, LiveParticipant p, {required bool isHost}) {
final svc = context.read<LiveRoomService>();
showModalBottomSheet(
context: context,
backgroundColor: PandaColors.bgCard,
shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
builder: (_) => Padding(
padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
Row(children: [
Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
const Spacer(),
IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close, color: Colors.white)),
]),
const SizedBox(height: 6),
Row(children: [
_ActionChip(icon: p.isMuted ? Icons.mic_off : Icons.mic, label: p.isMuted ? 'Unmute' : 'Mute', onTap: () { svc.toggleMute(p.id); context.pop(); }),
const SizedBox(width: 8),
_ActionChip(icon: p.isSpeaker ? Icons.arrow_downward : Icons.arrow_upward, label: p.isSpeaker ? 'Move to audience' : 'Make speaker', onTap: () { svc.promoteToSpeaker(p.id, makeSpeaker: !p.isSpeaker); context.pop(); }),
const SizedBox(width: 8),
if (isHost && !p.isHost) _ActionChip(icon: Icons.remove_circle, label: 'Remove', danger: true, onTap: () { svc.kickParticipant(p.id); context.pop(); }),
]),
]),
),
);
}
}

class _SpeakerTile extends StatelessWidget {
final LiveParticipant participant;
final bool isVideo;
final VoidCallback? onLongPress;
const _SpeakerTile({required this.participant, required this.isVideo, this.onLongPress});

@override
Widget build(BuildContext context) {
return GestureDetector(
onLongPress: onLongPress,
child: Container(
decoration: BoxDecoration(
color: PandaColors.bgCard,
borderRadius: BorderRadius.circular(AppRadius.lg),
border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35)),
),
child: Stack(children: [
if (isVideo)
Container(
decoration: BoxDecoration(
gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.1)]),
borderRadius: BorderRadius.circular(AppRadius.lg),
),
child: const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 48)),
)
else
const SizedBox.shrink(),
Center(child: ParticipantAvatar(participant: participant, showWave: !participant.isMuted)),
]),
),
);
}
}

class _BottomControls extends StatelessWidget {
final LiveParticipant me;
const _BottomControls({required this.me});

@override
Widget build(BuildContext context) {
final svc = context.read<LiveRoomService>();
return SafeArea(
top: false,
child: Container(
padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
decoration: BoxDecoration(color: PandaColors.bgCard, border: Border(top: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.3)))),
child: Row(children: [
_RoundBtn(icon: me.isMuted ? Icons.mic_off : Icons.mic, label: me.isMuted ? 'Unmute' : 'Mute', onTap: () => svc.toggleMeMute()),
const SizedBox(width: 12),
_RoundBtn(icon: Icons.front_hand, label: 'Hand', onTap: () {
  final id = svc.myParticipantId;
  if (id != null) svc.toggleHandRaise(id);
}),
const SizedBox(width: 12),
if (me.isHost) _RoundBtn(icon: Icons.group, label: 'Mute all', onTap: () => _muteAll(context)),
const Spacer(),
GestureDetector(
onTap: () async {
final active = context.read<LiveRoomService>().activeRoom;
if (active != null) await context.read<LiveRoomService>().endRoom(active.id);
if (context.mounted) context.pop();
},
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
decoration: BoxDecoration(
gradient: const LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFFF5252)]),
borderRadius: BorderRadius.circular(AppRadius.full),
),
child: Row(children: const [Icon(Icons.call_end, color: Colors.white), SizedBox(width: 6), Text('Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]),
),
),
]),
),
);
}

void _muteAll(BuildContext context) {
final svc = context.read<LiveRoomService>();
final room = svc.activeRoom;
if (room == null) return;
for (final p in room.participants) {
if (!p.isHost) {
svc.toggleMute(p.id);
}
}
}
}

class _ActionChip extends StatelessWidget {
final IconData icon; final String label; final VoidCallback onTap; final bool danger;
const _ActionChip({required this.icon, required this.label, required this.onTap, this.danger = false});
@override
Widget build(BuildContext context) {
return GestureDetector(
onTap: onTap,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
decoration: BoxDecoration(
color: danger ? const Color(0xFF3A1120) : PandaColors.bgInput,
borderRadius: BorderRadius.circular(AppRadius.full),
border: Border.all(color: danger ? Colors.redAccent.withValues(alpha: 0.5) : PandaColors.borderColor.withValues(alpha: 0.4)),
),
child: Row(children: [Icon(icon, color: danger ? Colors.redAccent : Colors.white, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: danger ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w700, fontSize: 12))]),
),
);
}
}

class _RoundBtn extends StatelessWidget {
final IconData icon; final String label; final VoidCallback onTap;
const _RoundBtn({required this.icon, required this.label, required this.onTap});
@override
Widget build(BuildContext context) {
return Column(children: [
GestureDetector(
onTap: onTap,
child: Container(
width: 52, height: 52,
decoration: BoxDecoration(
gradient: PandaColors.gradientButton,
shape: BoxShape.circle,
boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 12)],
),
child: Icon(icon, color: Colors.white),
),
),
const SizedBox(height: 6),
Text(label, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 11)),
]);
}
}
