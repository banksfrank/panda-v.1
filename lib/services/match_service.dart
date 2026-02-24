import 'package:flutter/foundation.dart';
import 'package:panda_dating_app/models/match.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';

class MatchService extends ChangeNotifier {
  List<Match> _matches = [];
  bool _isLoading = false;

  List<Match> get matches => _matches;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = SupabaseBootstrap.client;
      final myId = supabase?.auth.currentUser?.id;
      if (supabase == null || myId == null) {
        _matches = _seedDemoMatches();
        return;
      }

      await _initializeFromSupabase(supabase: supabase, myId: myId);
    } catch (e) {
      debugPrint('Failed to initialize matches: $e');
      _matches = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeFromSupabase({required dynamic supabase, required String myId}) async {
    // A match exists if both users have a `like` swipe on each other.
    final myLikes = await supabase.from('swipes').select('target_id,created_at').eq('swiper_id', myId).eq('action', 'like');
    final likedIds = (myLikes as List).map((e) => (e['target_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    if (likedIds.isEmpty) {
      _matches = [];
      return;
    }

    final reciprocal = await supabase.from('swipes').select('swiper_id,created_at').inFilter('swiper_id', likedIds).eq('target_id', myId).eq('action', 'like');
    final matchedUserIds = (reciprocal as List).map((e) => (e['swiper_id'] ?? '').toString()).where((id) => id.isNotEmpty).toSet().toList();
    if (matchedUserIds.isEmpty) {
      _matches = [];
      return;
    }

    final profiles = await supabase
        .from('profiles')
        .select('id,name,age,bio,location,city,country,profession,tribe,phone,date_of_birth,photos,interests,gender,looking_for,created_at,updated_at')
        .inFilter('id', matchedUserIds);

    final byId = <String, User>{};
    for (final row in (profiles as List)) {
      final u = _profileRowToUser(row);
      byId[u.id] = u;
    }

    final now = DateTime.now();
    _matches = matchedUserIds
        .where((id) => byId.containsKey(id))
        .map((id) => Match(
              id: 'match_${myId}_$id',
              user: byId[id]!,
              matchedAt: now,
              lastMessage: null,
              lastMessageTime: null,
              isRead: true,
            ))
        .toList();
  }

  User _profileRowToUser(dynamic row) {
    final now = DateTime.now();
    DateTime? tryParseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return User(
      id: (row['id'] ?? '').toString(),
      name: (row['name'] ?? 'Panda User').toString(),
      age: (row['age'] is int) ? row['age'] as int : int.tryParse('${row['age']}') ?? 18,
      bio: (row['bio'] ?? '').toString(),
      location: (row['location'] ?? 'Location not set').toString(),
      city: row['city'] as String?,
      country: row['country'] as String?,
      profession: row['profession'] as String?,
      tribe: row['tribe'] as String?,
      phone: row['phone'] as String?,
      dateOfBirth: tryParseDate(row['date_of_birth']),
      photos: (row['photos'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      interests: (row['interests'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
      gender: (row['gender'] ?? 'Not specified').toString(),
      lookingFor: (row['looking_for'] ?? 'Not specified').toString(),
      createdAt: tryParseDate(row['created_at']) ?? now,
      updatedAt: tryParseDate(row['updated_at']) ?? now,
    );
  }

  List<Match> _seedDemoMatches() {
    final now = DateTime.now();
    final demoUsers = [
      User(
        id: 'demo_match_1',
        name: 'Lina',
        age: 26,
        bio: 'If you like sunsets and street food, we’ll get along.',
        location: 'Kigali',
        city: 'Kigali',
        country: 'Rwanda',
        profession: 'Photographer',
        tribe: null,
        phone: null,
        dateOfBirth: null,
        photos: const ['https://images.unsplash.com/photo-1524503033411-f2b3c8a7f76b?w=800'],
        interests: const ['Photography', 'Travel', 'Food'],
        gender: 'Woman',
        lookingFor: 'Dating',
        createdAt: now,
        updatedAt: now,
      ),
      User(
        id: 'demo_match_2',
        name: 'Sam',
        age: 30,
        bio: 'Weekend hikes, weekday playlists. Let’s chat.',
        location: 'Johannesburg',
        city: 'Johannesburg',
        country: 'South Africa',
        profession: 'DJ',
        tribe: null,
        phone: null,
        dateOfBirth: null,
        photos: const ['https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800'],
        interests: const ['Music', 'Hiking', 'Coffee'],
        gender: 'Man',
        lookingFor: 'Relationship',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    return [
      Match(
        id: 'demo_match_lina',
        user: demoUsers[0],
        matchedAt: now.subtract(const Duration(days: 2)),
        lastMessage: 'Hey! Want to grab coffee this weekend?',
        lastMessageTime: now.subtract(const Duration(hours: 6)),
        isRead: false,
      ),
      Match(
        id: 'demo_match_sam',
        user: demoUsers[1],
        matchedAt: now.subtract(const Duration(days: 5)),
        lastMessage: 'New track just dropped — sending you the link!',
        lastMessageTime: now.subtract(const Duration(days: 1, hours: 3)),
        isRead: true,
      ),
    ];
  }

  Future<void> updateMatch(Match match) async {
    final index = _matches.indexWhere((m) => m.id == match.id);
    if (index == -1) return;
    _matches[index] = match;
    notifyListeners();
  }

  Future<void> removeMatch(String id) async {
    final match = _matches.cast<Match?>().firstWhere((m) => m?.id == id, orElse: () => null);
    _matches.removeWhere((m) => m.id == id);

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase != null && myId != null && match != null) {
      // Remove *your* like to break the match (you can’t delete the other user’s swipe under RLS).
      try {
        await supabase.from('swipes').delete().eq('swiper_id', myId).eq('target_id', match.user.id).eq('action', 'like');
      } catch (e) {
        debugPrint('Supabase removeMatch failed: $e');
      }
    }

    notifyListeners();
  }
}
