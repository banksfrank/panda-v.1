import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/models/live_room.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/services/live_room_service.dart';
import 'package:panda_dating_app/widgets/room_card.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/widgets/panda_app_header.dart';
import 'package:panda_dating_app/widgets/panda_sheets.dart';

class LiveRoomsScreen extends StatefulWidget {
  const LiveRoomsScreen({super.key});

  @override
  State<LiveRoomsScreen> createState() => _LiveRoomsScreenState();
}

class _LiveRoomsScreenState extends State<LiveRoomsScreen> {
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveRoomService>().initialize();
    });
  }

  Future<void> _startRoom() async {
    final titleController = TextEditingController();
    final topicController = TextEditingController();
    LiveRoomType selectedType = LiveRoomType.audio;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Host a room', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('TYPE', style: TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setModalState) {
                  Widget chip(String label, LiveRoomType type, IconData icon) {
                    final active = selectedType == type;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: active ? PandaColors.gradientButton : null,
                          color: active ? null : PandaColors.bgInput,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: active ? Colors.white : PandaColors.textMuted, size: 18),
                            const SizedBox(width: 8),
                            Text(label, style: TextStyle(color: active ? Colors.white : PandaColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }

                  return Row(
                    children: [
                      chip('Audio', LiveRoomType.audio, Icons.mic),
                      const SizedBox(width: 10),
                      chip('Video', LiveRoomType.video, Icons.videocam),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text('TITLE', style: TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              _SheetTextField(controller: titleController, hintText: 'My Live Room'),
              const SizedBox(height: 12),
              const Text('TOPIC', style: TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              _SheetTextField(controller: topicController, hintText: 'What are we talking about?'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                  child: Ink(
                    decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 14)]),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: Text('Go live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    final auth = context.read<AuthService>();
    final hostName = auth.currentUser?.name ?? 'You';

    final id = await context.read<LiveRoomService>().createRoom(
          hostName: hostName,
          type: selectedType,
          title: titleController.text,
          topic: topicController.text,
        );

    if (!mounted) return;
    context.push('/live-room/$id');
  }

  @override
  Widget build(BuildContext context) {
    const filters = <String, String>{'all': 'All', 'audio': 'Audio', 'video': 'Video', 'private': 'Private'};

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PandaColors.bgPrimary, PandaColors.bgSecondary]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              PandaAppHeader(
                title: Row(
                  children: [
                    ShaderMask(shaderCallback: (b) => PandaColors.gradientPrimary.createShader(b), child: const Text('Live Rooms', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
                    const Spacer(),
                    GestureDetector(
                      onTap: _startRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.22), blurRadius: 12)]),
                        child: Row(children: const [Icon(Icons.add, color: Colors.white, size: 18), SizedBox(width: 6), Text('Host', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))]),
                      ),
                    ),
                  ],
                ),
                onTapAi: () => AiAssistantSheet.show(context),
                onTapNotifications: () => NotificationsSheet.show(context),
                onTapPremium: () => PremiumSheet.show(context),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final key = filters.keys.elementAt(i);
                    final label = filters[key]!;
                    final active = key == _activeFilter;
                    return GestureDetector(
                      onTap: () => setState(() => _activeFilter = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: active ? PandaColors.gradientButton : null,
                          color: active ? null : PandaColors.bgCard,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(label, style: TextStyle(color: active ? Colors.white : PandaColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: filters.length,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Consumer<LiveRoomService>(
                  builder: (context, service, _) {
                    if (service.isLoading) return const Center(child: CircularProgressIndicator(color: PandaColors.pink));
                    final list = service.rooms.where((r) => _matchesFilter(r)).toList();
                    if (list.isEmpty) return const Center(child: Text('No rooms available', style: TextStyle(color: PandaColors.textMuted)));

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (_, i) => RoomCard(room: list[i], onJoin: () => context.push('/live-room/${list[i].id}')),
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemCount: list.length,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(LiveRoom room) {
    switch (_activeFilter) {
      case 'audio':
        return room.type == LiveRoomType.audio;
      case 'video':
        return room.type == LiveRoomType.video;
      case 'private':
        return room.participants.length <= 4;
      default:
        return true;
    }
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  const _SheetTextField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PandaColors.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: PandaColors.borderColor, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: PandaColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: PandaColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
