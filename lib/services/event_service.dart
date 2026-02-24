import 'package:flutter/foundation.dart';
import 'package:panda_dating_app/models/event.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';

class EventService extends ChangeNotifier {
  List<EventModel> _events = [];
  final Set<String> _rsvps = {};
  bool _isLoading = false;

  List<EventModel> get events => _events;
  bool get isLoading => _isLoading;
  Set<String> get rsvps => _rsvps;

  String? get _myId => SupabaseBootstrap.client?.auth.currentUser?.id;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = SupabaseBootstrap.client;
      final myId = _myId;
      if (supabase == null || myId == null) {
        _events = _seedDemoEvents();
        _rsvps
          ..clear()
          ..addAll({'demo_event_1'});
        return;
      }

      await _initializeFromSupabase(supabase: supabase, myId: myId);
    } catch (e) {
      debugPrint('Failed to initialize events from Supabase: $e');
      _events = [];
      _rsvps.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<EventModel> _seedDemoEvents() {
    final now = DateTime.now();
    return [
      EventModel(
        id: 'demo_event_1',
        title: 'Speed Dating: City Rooftop',
        description: 'Quick rounds, good vibes, and a curated crowd. Dress code: smart casual.',
        startTime: now.add(const Duration(days: 1, hours: 19)),
        endTime: now.add(const Duration(days: 1, hours: 22)),
        location: 'Downtown Rooftop • RSVP to get address',
        type: 'speed_dating',
        format: 'in_person',
        capacity: 60,
        rsvpCount: 24,
        tags: const ['culture', 'music', 'fun'],
        bannerEmoji: '💘',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      EventModel(
        id: 'demo_event_2',
        title: 'Online Mixer: Coffee & Chats',
        description: 'Join a relaxed online mixer with icebreakers and breakout rooms.',
        startTime: now.add(const Duration(days: 3, hours: 18)),
        endTime: now.add(const Duration(days: 3, hours: 20)),
        location: 'Zoom link shared after RSVP',
        type: 'mixer',
        format: 'online',
        capacity: 120,
        rsvpCount: 78,
        tags: const ['online', 'network'],
        bannerEmoji: '☕',
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      EventModel(
        id: 'demo_event_3',
        title: 'Professional Networking Night',
        description: 'Meet ambitious people, swap stories, and maybe find your person.',
        startTime: now.add(const Duration(days: 7, hours: 18)),
        endTime: now.add(const Duration(days: 7, hours: 21)),
        location: 'Business District Lounge',
        type: 'professional',
        format: 'in_person',
        capacity: 90,
        rsvpCount: 41,
        tags: const ['network', 'career'],
        bannerEmoji: '🧠',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  Future<void> _initializeFromSupabase({required dynamic supabase, required String myId}) async {
    // Load RSVP state for current user.
    try {
      final rsvpRows = await supabase.from('event_rsvps').select('event_id').eq('user_id', myId);
      _rsvps
        ..clear()
        ..addAll((rsvpRows as List).map((e) => (e['event_id'] ?? '').toString()).where((id) => id.isNotEmpty));
    } catch (e) {
      debugPrint('Failed to load event_rsvps: $e');
      _rsvps.clear();
    }

    final rows = await supabase
        .from('events')
        .select('id,title,description,start_time,end_time,location,type,format,capacity,rsvp_count,tags,banner_emoji,created_at,updated_at')
        .order('start_time');

    _events = (rows as List).map(_rowToEvent).toList();
  }

  EventModel _rowToEvent(dynamic row) {
    DateTime parse(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    return EventModel(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? 'Event').toString(),
      description: (row['description'] ?? '').toString(),
      startTime: parse(row['start_time']),
      endTime: parse(row['end_time']),
      location: (row['location'] ?? 'TBA').toString(),
      type: (row['type'] ?? 'mixer').toString(),
      format: (row['format'] ?? 'online').toString(),
      capacity: (row['capacity'] is int) ? row['capacity'] as int : int.tryParse('${row['capacity']}') ?? 50,
      rsvpCount: (row['rsvp_count'] is int) ? row['rsvp_count'] as int : int.tryParse('${row['rsvp_count']}') ?? 0,
      tags: (row['tags'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      bannerEmoji: (row['banner_emoji'] ?? '🎉').toString(),
      createdAt: parse(row['created_at']),
      updatedAt: parse(row['updated_at']),
    );
  }

  Future<void> toggleRsvp(String eventId) async {
    final supabase = SupabaseBootstrap.client;
    final myId = _myId;
    if (supabase == null || myId == null) {
      final isRsvped = _rsvps.contains(eventId);
      if (isRsvped) {
        _rsvps.remove(eventId);
      } else {
        _rsvps.add(eventId);
      }
      _events = _events
          .map((e) => e.id == eventId ? e.copyWith(rsvpCount: (e.rsvpCount + (isRsvped ? -1 : 1)).clamp(0, 999999), updatedAt: DateTime.now()) : e)
          .toList();
      notifyListeners();
      return;
    }

    try {
      final isRsvped = _rsvps.contains(eventId);
      if (isRsvped) {
        await supabase.from('event_rsvps').delete().eq('event_id', eventId).eq('user_id', myId);
        _rsvps.remove(eventId);
      } else {
        await supabase.from('event_rsvps').insert({'event_id': eventId, 'user_id': myId});
        _rsvps.add(eventId);
      }

      // Refresh the event row so count stays accurate (trigger-based).
      try {
        final row = await supabase
            .from('events')
            .select('id,title,description,start_time,end_time,location,type,format,capacity,rsvp_count,tags,banner_emoji,created_at,updated_at')
            .eq('id', eventId)
            .maybeSingle();
        if (row != null) {
          final updated = _rowToEvent(row);
          _events = _events.map((e) => e.id == eventId ? updated : e).toList();
        }
      } catch (e) {
        debugPrint('Failed to refresh event after RSVP: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Supabase toggleRsvp failed: $e');
    }
  }

  Future<String> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required String type,
    required String format,
    required int capacity,
    List<String> tags = const [],
    String bannerEmoji = '🎉',
  }) async {
    final supabase = SupabaseBootstrap.client;
    final myId = _myId;
    if (supabase == null || myId == null) {
      final now = DateTime.now();
      final event = EventModel(
        id: 'local_event_${now.microsecondsSinceEpoch}',
        title: title.trim().isEmpty ? 'New Event' : title.trim(),
        description: description.trim(),
        startTime: startTime,
        endTime: endTime.isAfter(startTime) ? endTime : startTime.add(const Duration(hours: 2)),
        location: location.trim().isEmpty ? 'TBA' : location.trim(),
        type: type,
        format: format,
        capacity: capacity.clamp(2, 9999),
        rsvpCount: 0,
        tags: tags,
        bannerEmoji: bannerEmoji,
        createdAt: now,
        updatedAt: now,
      );
      _events = [event, ..._events];
      notifyListeners();
      return event.id;
    }

    try {
      final inserted = await supabase
          .from('events')
          .insert({
            'title': title.trim().isEmpty ? 'New Event' : title.trim(),
            'description': description.trim(),
            'start_time': startTime.toIso8601String(),
            'end_time': (endTime.isAfter(startTime) ? endTime : startTime.add(const Duration(hours: 2))).toIso8601String(),
            'location': location.trim().isEmpty ? 'TBA' : location.trim(),
            'type': type,
            'format': format,
            'capacity': capacity.clamp(2, 9999),
            'tags': tags,
            'banner_emoji': bannerEmoji,
            'created_by': myId,
          })
          .select('id,title,description,start_time,end_time,location,type,format,capacity,rsvp_count,tags,banner_emoji,created_at,updated_at')
          .single();

      final event = _rowToEvent(inserted);
      _events = [event, ..._events];
      notifyListeners();
      return event.id;
    } catch (e) {
      debugPrint('Supabase createEvent failed: $e');
      rethrow;
    }
  }
}
