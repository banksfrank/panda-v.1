import 'package:flutter/foundation.dart';
import 'package:panda_dating_app/models/live_participant.dart';
import 'package:panda_dating_app/models/live_room.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';

class LiveRoomService extends ChangeNotifier {
  List<LiveRoom> _rooms = [];
  LiveRoom? _activeRoom;
  bool _isLoading = false;

  List<LiveRoom> get rooms => _rooms;
  LiveRoom? get activeRoom => _activeRoom;
  bool get isLoading => _isLoading;

  String? get myParticipantId => SupabaseBootstrap.client?.auth.currentUser?.id;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = SupabaseBootstrap.client;
      final myId = supabase?.auth.currentUser?.id;
      if (supabase == null || myId == null) {
        _rooms = _seedDemoRooms();
        _activeRoom = null;
        return;
      }

      await _initializeFromSupabase(supabase: supabase);
    } catch (e) {
      debugPrint('Failed to initialize live rooms from Supabase: $e');
      _rooms = [];
      _activeRoom = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<LiveRoom> _seedDemoRooms() {
    final now = DateTime.now();
    return [
      LiveRoom(
        id: 'demo_room_1',
        title: 'Late-night Tea & Talks',
        topic: 'Unpopular opinions (keep it respectful)',
        type: LiveRoomType.audio,
        isLive: true,
        isRecording: false,
        hostId: 'demo_host_1',
        participants: [
          LiveParticipant(id: 'demo_host_1', displayName: 'Host Maya', isHost: true, isSpeaker: true, isMuted: false, handRaised: false, cameraOn: false, createdAt: now, updatedAt: now),
          LiveParticipant(id: 'demo_guest_1', displayName: 'Ken', isHost: false, isSpeaker: true, isMuted: true, handRaised: false, cameraOn: false, createdAt: now, updatedAt: now),
          LiveParticipant(id: 'demo_guest_2', displayName: 'Zee', isHost: false, isSpeaker: false, isMuted: true, handRaised: true, cameraOn: false, createdAt: now, updatedAt: now),
        ],
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(minutes: 10)),
      ),
      LiveRoom(
        id: 'demo_room_2',
        title: 'Mini Speed-Friendship',
        topic: '3 questions • 3 minutes each',
        type: LiveRoomType.video,
        isLive: false,
        isRecording: false,
        hostId: 'demo_host_2',
        participants: [
          LiveParticipant(id: 'demo_host_2', displayName: 'Host Tobi', isHost: true, isSpeaker: true, isMuted: false, handRaised: false, cameraOn: true, createdAt: now, updatedAt: now),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  Future<void> _initializeFromSupabase({required dynamic supabase}) async {
    final rows = await supabase
        .from('live_rooms')
        .select('id,title,topic,type,is_live,is_recording,host_id,created_at,updated_at')
        .order('updated_at', ascending: false);

    final rooms = <LiveRoom>[];
    for (final r in (rows as List)) {
      rooms.add(_roomRowToModel(r, participants: const []));
    }
    _rooms = rooms;
  }

  LiveRoom _roomRowToModel(dynamic row, {required List<LiveParticipant> participants}) {
    DateTime parse(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    final typeRaw = (row['type'] ?? 'audio').toString();
    final type = typeRaw == 'video' ? LiveRoomType.video : LiveRoomType.audio;

    return LiveRoom(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? 'Live room').toString(),
      topic: (row['topic'] ?? '').toString(),
      type: type,
      isLive: row['is_live'] == true,
      isRecording: row['is_recording'] == true,
      hostId: (row['host_id'] ?? '').toString(),
      participants: participants,
      createdAt: parse(row['created_at']),
      updatedAt: parse(row['updated_at']),
    );
  }

  LiveParticipant _participantRowToModel(dynamic row) {
    DateTime parse(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    return LiveParticipant(
      id: (row['user_id'] ?? '').toString(),
      displayName: (row['display_name'] ?? 'Guest').toString(),
      isHost: row['is_host'] == true,
      isSpeaker: row['is_speaker'] == true,
      isMuted: row['is_muted'] == true,
      handRaised: row['hand_raised'] == true,
      cameraOn: row['camera_on'] == true,
      createdAt: parse(row['created_at'] ?? row['joined_at']),
      updatedAt: parse(row['updated_at']),
    );
  }

  Future<LiveRoom?> _fetchRoomFromSupabase({required dynamic supabase, required String roomId}) async {
    try {
      final roomRow = await supabase
          .from('live_rooms')
          .select('id,title,topic,type,is_live,is_recording,host_id,created_at,updated_at')
          .eq('id', roomId)
          .maybeSingle();
      if (roomRow == null) return null;

      final participantRows = await supabase
          .from('live_room_participants')
          .select('room_id,user_id,display_name,is_host,is_speaker,is_muted,hand_raised,camera_on,joined_at,created_at,updated_at')
          .eq('room_id', roomId)
          .order('joined_at');

      final participants = (participantRows as List).map(_participantRowToModel).toList();
      return _roomRowToModel(roomRow, participants: participants);
    } catch (e) {
      debugPrint('Failed to fetch room from Supabase: $e');
      return null;
    }
  }

  Future<String> createRoom({required String hostName, required LiveRoomType type, String? title, String? topic}) async {
    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) {
      final now = DateTime.now();
      final roomId = 'local_room_${now.microsecondsSinceEpoch}';
      final room = LiveRoom(
        id: roomId,
        title: (title?.trim().isNotEmpty ?? false) ? title!.trim() : 'My Live Room',
        topic: (topic?.trim().isNotEmpty ?? false) ? topic!.trim() : 'Say hi and meet new people',
        type: type,
        isLive: true,
        isRecording: false,
        hostId: 'demo_user',
        participants: [
          LiveParticipant(
            id: 'demo_user',
            displayName: hostName.trim().isNotEmpty ? hostName.trim() : 'You',
            isHost: true,
            isSpeaker: true,
            isMuted: false,
            handRaised: false,
            cameraOn: type == LiveRoomType.video,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      _activeRoom = room;
      _rooms = [room, ..._rooms];
      notifyListeners();
      return roomId;
    }

    try {
      final now = DateTime.now();
      final inserted = await supabase
          .from('live_rooms')
          .insert({
            'title': (title?.trim().isNotEmpty ?? false) ? title!.trim() : 'My Live Room',
            'topic': (topic?.trim().isNotEmpty ?? false) ? topic!.trim() : 'Say hi and meet new people',
            'type': type.name,
            'is_live': true,
            'is_recording': false,
            'host_id': myId,
          })
          .select('id')
          .single();

      final roomId = (inserted['id'] ?? '').toString();
      if (roomId.isEmpty) throw Exception('live_rooms insert returned empty id');

      await supabase.from('live_room_participants').upsert({
        'room_id': roomId,
        'user_id': myId,
        'display_name': hostName,
        'is_host': true,
        'is_speaker': true,
        'is_muted': false,
        'hand_raised': false,
        'camera_on': type == LiveRoomType.video,
        'joined_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final hydrated = await _fetchRoomFromSupabase(supabase: supabase, roomId: roomId);
      if (hydrated != null) _activeRoom = hydrated;

      await initialize();
      notifyListeners();
      return roomId;
    } catch (e) {
      debugPrint('Supabase createRoom failed: $e');
      rethrow;
    }
  }

  Future<void> joinRoom(String roomId, {required String userName, bool asHost = false}) async {
    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) {
      final room = _rooms.cast<LiveRoom?>().firstWhere((r) => r?.id == roomId, orElse: () => null);
      if (room == null) return;

      final now = DateTime.now();
      final me = LiveParticipant(
        id: 'demo_user',
        displayName: userName.trim().isNotEmpty ? userName.trim() : 'You',
        isHost: asHost,
        isSpeaker: asHost,
        isMuted: !asHost,
        handRaised: false,
        cameraOn: room.type == LiveRoomType.video && asHost,
        createdAt: now,
        updatedAt: now,
      );

      final updated = room.copyWith(
        participants: [...room.participants.where((p) => p.id != me.id), me],
        updatedAt: now,
      );

      _rooms = _rooms.map((r) => r.id == roomId ? updated : r).toList();
      _activeRoom = updated;
      notifyListeners();
      return;
    }

    try {
      final now = DateTime.now();
      final room = await supabase.from('live_rooms').select('host_id,type').eq('id', roomId).maybeSingle();
      if (room == null) throw Exception('Room not found');

      final hostId = (room['host_id'] ?? '').toString();
      final typeRaw = (room['type'] ?? 'audio').toString();
      final isVideo = typeRaw == 'video';

      await supabase.from('live_room_participants').upsert({
        'room_id': roomId,
        'user_id': myId,
        'display_name': userName,
        'is_host': asHost || hostId == myId,
        'is_speaker': asHost || hostId == myId,
        'is_muted': true,
        'hand_raised': false,
        'camera_on': isVideo && (asHost || hostId == myId),
        'joined_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final hydrated = await _fetchRoomFromSupabase(supabase: supabase, roomId: roomId);
      if (hydrated != null) {
        _activeRoom = hydrated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Supabase joinRoom failed: $e');
    }
  }

  Future<void> leaveActiveRoom() async {
    final room = _activeRoom;
    if (room == null) return;

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      await supabase.from('live_room_participants').delete().eq('room_id', room.id).eq('user_id', myId);
    } catch (e) {
      debugPrint('Supabase leaveActiveRoom failed: $e');
    } finally {
      _activeRoom = null;
      notifyListeners();
    }
  }

  Future<void> _refreshActiveFromSupabase() async {
    final supabase = SupabaseBootstrap.client;
    final roomId = _activeRoom?.id;
    if (supabase == null || roomId == null) return;

    final hydrated = await _fetchRoomFromSupabase(supabase: supabase, roomId: roomId);
    if (hydrated != null) {
      _activeRoom = hydrated;
      notifyListeners();
    }
  }

  Future<void> toggleMute(String participantId) async {
    final room = _activeRoom;
    if (room == null) return;

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      final current = room.participants.cast<LiveParticipant?>().firstWhere((p) => p?.id == participantId, orElse: () => null);
      if (current == null) return;

      await supabase
          .from('live_room_participants')
          .update({'is_muted': !current.isMuted, 'updated_at': DateTime.now().toIso8601String()})
          .eq('room_id', room.id)
          .eq('user_id', participantId);

      await _refreshActiveFromSupabase();
    } catch (e) {
      debugPrint('Supabase toggleMute failed: $e');
    }
  }

  Future<void> toggleMeMute() async {
    final myId = myParticipantId;
    if (myId == null) return;
    await toggleMute(myId);
  }

  Future<void> toggleHandRaise(String participantId) async {
    final room = _activeRoom;
    if (room == null) return;

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      final current = room.participants.cast<LiveParticipant?>().firstWhere((p) => p?.id == participantId, orElse: () => null);
      if (current == null) return;

      await supabase
          .from('live_room_participants')
          .update({'hand_raised': !current.handRaised, 'updated_at': DateTime.now().toIso8601String()})
          .eq('room_id', room.id)
          .eq('user_id', participantId);

      await _refreshActiveFromSupabase();
    } catch (e) {
      debugPrint('Supabase toggleHandRaise failed: $e');
    }
  }

  Future<void> promoteToSpeaker(String participantId, {required bool makeSpeaker}) async {
    final room = _activeRoom;
    if (room == null) return;

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      await supabase
          .from('live_room_participants')
          .update({'is_speaker': makeSpeaker, 'hand_raised': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('room_id', room.id)
          .eq('user_id', participantId);

      await _refreshActiveFromSupabase();
    } catch (e) {
      debugPrint('Supabase promoteToSpeaker failed: $e');
    }
  }

  Future<void> kickParticipant(String participantId) async {
    final room = _activeRoom;
    if (room == null) return;

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      await supabase.from('live_room_participants').delete().eq('room_id', room.id).eq('user_id', participantId);
      await _refreshActiveFromSupabase();
    } catch (e) {
      debugPrint('Supabase kickParticipant failed: $e');
    }
  }

  Future<void> toggleRecording() async {
    final room = _activeRoom;
    if (room == null) return;

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      await supabase.from('live_rooms').update({'is_recording': !room.isRecording, 'updated_at': DateTime.now().toIso8601String()}).eq('id', room.id);
      await _refreshActiveFromSupabase();
      await initialize();
    } catch (e) {
      debugPrint('Supabase toggleRecording failed: $e');
    }
  }

  Future<void> endRoom(String roomId) async {
    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase == null || myId == null) return;

    try {
      await supabase.from('live_rooms').update({'is_live': false, 'updated_at': DateTime.now().toIso8601String()}).eq('id', roomId);
      if (_activeRoom?.id == roomId) _activeRoom = _activeRoom?.copyWith(isLive: false, updatedAt: DateTime.now());
      await initialize();
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase endRoom failed: $e');
    }
  }
}
