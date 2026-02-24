import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';
import 'package:panda_dating_app/utils/seeded_identity.dart';

class DiscoveryFilters {
  final int ageMin;
  final int ageMax;
  final String? country;
  final String? city;
  final String? professionQuery;
  final Set<String> interests;

  const DiscoveryFilters({required this.ageMin, required this.ageMax, this.country, this.city, this.professionQuery, this.interests = const {}});

  DiscoveryFilters copyWith({int? ageMin, int? ageMax, String? country, String? city, String? professionQuery, Set<String>? interests}) => DiscoveryFilters(
    ageMin: ageMin ?? this.ageMin,
    ageMax: ageMax ?? this.ageMax,
    country: country ?? this.country,
    city: city ?? this.city,
    professionQuery: professionQuery ?? this.professionQuery,
    interests: interests ?? this.interests,
  );

  static const defaults = DiscoveryFilters(ageMin: 18, ageMax: 50);
}

class DiscoveryService extends ChangeNotifier {
  static const _swipeKey = 'swipe_state_v1';
  static const _demoLikedKey = 'demo_likes_v1';

  final List<User> _allProfiles = [];
  List<User> _availableProfiles = [];
  List<String> _likedProfiles = [];
  bool _isLoading = false;

  DiscoveryFilters _filters = DiscoveryFilters.defaults;

  int _swipesRemaining = 10;
  DateTime _swipeDay = DateTime.now();

  List<User> get availableProfiles => _availableProfiles;
  bool get isLoading => _isLoading;
  DiscoveryFilters get filters => _filters;
  int get swipesRemaining => _swipesRemaining;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadSwipeLimiterFromLocal();

      final supabase = SupabaseBootstrap.client;
      final myId = supabase?.auth.currentUser?.id;
      if (supabase == null || myId == null) {
        await _initializeFromLocalDemo();
        _resetSwipesIfNeeded();
        _applyFiltersInternal();
        return;
      }

      await _initializeFromSupabase(supabase: supabase, myId: myId);
      _resetSwipesIfNeeded();
      _applyFiltersInternal();
    } catch (e) {
      debugPrint('Failed to initialize discovery: $e');
      _allProfiles.clear();
      _availableProfiles = [];
      _likedProfiles = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadSwipeLimiterFromLocal() async {
    // Swipes remaining is a UX-only premium limiter; we keep this locally even with Supabase.
    try {
      final prefs = await SharedPreferences.getInstance();
      final swipeRaw = prefs.getString(_swipeKey);
      if (swipeRaw != null) {
        final parts = swipeRaw.split('|');
        if (parts.length == 2) {
          final day = DateTime.tryParse(parts[0]);
          final remaining = int.tryParse(parts[1]);
          if (day != null && remaining != null) {
            _swipeDay = day;
            _swipesRemaining = remaining;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load swipe limiter: $e');
    }
  }

  Future<void> _initializeFromLocalDemo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _likedProfiles = prefs.getStringList(_demoLikedKey) ?? [];

      _allProfiles
        ..clear()
        ..addAll(_seedDemoProfiles());
    } catch (e) {
      debugPrint('Failed to initialize local demo discovery: $e');
      _likedProfiles = [];
      _allProfiles
        ..clear()
        ..addAll(_seedDemoProfiles());
    }
  }

  List<User> _seedDemoProfiles() {
    final now = DateTime.now();

    // Deterministic demo identities: ONE identity per personId, locked by (lockedBaseSeed + personId).
    // We generate a larger pool so your discovery feed shows the requested country distribution.
    const seed = SeededIdentity.lockedBaseSeed;
    const total = 120;

    return List.generate(total, (i) {
      final personId = 'demo_${(i + 1).toString().padLeft(3, '0')}';
      final identity = SeededIdentity.build(seed: seed, personId: personId, photosPerProfile: 3);
      return User(
        id: identity.id,
        name: identity.name,
        age: identity.age,
        bio: identity.bio,
        location: identity.location,
        city: identity.city,
        country: identity.country,
        profession: identity.profession,
        tribe: identity.ethnicity,
        characterName: identity.name,
        generationPlatform: 'Local Demo',
        seedNumber: SeededIdentity.lockedBaseSeed,
        identityCreatedAt: now,
        identityNotes: 'Deterministic demo identity locked to seed + personId.',
        phone: null,
        dateOfBirth: null,
        photos: identity.photos,
        interests: identity.interests,
        gender: identity.gender,
        lookingFor: identity.lookingFor,
        createdAt: now,
        updatedAt: now,
      );
    }).toList(growable: false);
  }

  Future<void> _initializeFromSupabase({required dynamic supabase, required String myId}) async {
    try {
      final likedRows = await supabase.from('swipes').select('target_id').eq('swiper_id', myId).eq('action', 'like');
      _likedProfiles = (likedRows as List).map((e) => (e['target_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Failed to load Supabase swipes: $e');
      _likedProfiles = [];
    }

    final rows = await supabase
        .from('profiles')
        .select('id,name,age,bio,location,city,country,profession,tribe,phone,date_of_birth,photos,interests,gender,looking_for,created_at,updated_at,character_name,generation_platform,seed_number,identity_created_at,identity_notes')
        .neq('id', myId)
        .eq('is_active', true)
        .eq('is_discoverable', true)
        .order('updated_at', ascending: false)
        .limit(50);

    _allProfiles
      ..clear()
      ..addAll((rows as List).map(_profileRowToUser));
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
      characterName: row['character_name'] as String?,
      generationPlatform: row['generation_platform'] as String?,
      seedNumber: (row['seed_number'] ?? '').toString().trim().isEmpty ? null : (row['seed_number'] ?? '').toString(),
      identityCreatedAt: tryParseDate(row['identity_created_at']),
      identityNotes: row['identity_notes'] as String?,
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

  void _resetSwipesIfNeeded() {
    final now = DateTime.now();
    final sameDay = now.year == _swipeDay.year && now.month == _swipeDay.month && now.day == _swipeDay.day;
    if (!sameDay) {
      _swipeDay = DateTime(now.year, now.month, now.day);
      _swipesRemaining = 10;
      _persistSwipeState();
    }
  }

  Future<void> _persistSwipeState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_swipeKey, '${_swipeDay.toIso8601String()}|$_swipesRemaining');
    } catch (e) {
      debugPrint('Failed to persist swipe state: $e');
    }
  }

  void applyFilters(DiscoveryFilters filters) {
    _filters = filters;
    _applyFiltersInternal();
    notifyListeners();
  }

  void resetFilters() {
    _filters = DiscoveryFilters.defaults;
    _applyFiltersInternal();
    notifyListeners();
  }

  void _applyFiltersInternal() {
    final f = _filters;
    final q = (f.professionQuery ?? '').trim().toLowerCase();

    _availableProfiles = _allProfiles.where((p) {
      if (_likedProfiles.contains(p.id)) return false;
      if (p.age < f.ageMin || p.age > f.ageMax) return false;
      if (f.country != null && f.country!.trim().isNotEmpty) {
        if ((p.country ?? '').toLowerCase() != f.country!.toLowerCase()) return false;
      }
      if (f.city != null && f.city!.trim().isNotEmpty) {
        if ((p.city ?? '').toLowerCase() != f.city!.toLowerCase()) return false;
      }
      if (q.isNotEmpty) {
        final prof = (p.profession ?? '').toLowerCase();
        if (!prof.contains(q)) return false;
      }
      if (f.interests.isNotEmpty) {
        final theirs = p.interests.map((e) => e.toLowerCase()).toSet();
        if (!f.interests.any((i) => theirs.contains(i.toLowerCase()))) return false;
      }
      return true;
    }).toList();
  }

  bool canSwipe({required bool isPremium}) => isPremium || _swipesRemaining > 0;

  Future<void> _consumeSwipeIfNeeded({required bool isPremium}) async {
    if (isPremium) return;
    _resetSwipesIfNeeded();
    if (_swipesRemaining <= 0) return;
    _swipesRemaining -= 1;
    await _persistSwipeState();
  }

  Future<void> likeProfile(String userId, {required bool isPremium}) async {
    if (!canSwipe(isPremium: isPremium)) return;

    try {
      await _consumeSwipeIfNeeded(isPremium: isPremium);

      final supabase = SupabaseBootstrap.client;
      final myId = supabase?.auth.currentUser?.id;
      if (supabase == null || myId == null) {
        _likedProfiles.add(userId);
        _availableProfiles.removeWhere((p) => p.id == userId);
        notifyListeners();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_demoLikedKey, _likedProfiles);
        } catch (e) {
          debugPrint('Failed to persist demo like: $e');
        }
        return;
      }

      try {
        await supabase.from('swipes').insert({'swiper_id': myId, 'target_id': userId, 'action': 'like'});
      } catch (e) {
        debugPrint('Supabase swipe insert failed: $e');
      }

      _likedProfiles.add(userId);
      _availableProfiles.removeWhere((p) => p.id == userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to like profile: $e');
    }
  }

  Future<void> passProfile(String userId, {required bool isPremium}) async {
    if (!canSwipe(isPremium: isPremium)) return;
    await _consumeSwipeIfNeeded(isPremium: isPremium);

    final supabase = SupabaseBootstrap.client;
    final myId = supabase?.auth.currentUser?.id;
    if (supabase != null && myId != null) {
      try {
        await supabase.from('swipes').insert({'swiper_id': myId, 'target_id': userId, 'action': 'pass'});
      } catch (e) {
        debugPrint('Supabase pass swipe insert failed: $e');
      }
    }

    _availableProfiles.removeWhere((p) => p.id == userId);
    notifyListeners();
  }

  void reset() {
    _applyFiltersInternal();
    notifyListeners();
  }

  Future<void> resetDemo() async {
    try {
      final supabase = SupabaseBootstrap.client;
      final myId = supabase?.auth.currentUser?.id;
      if (supabase == null || myId == null) return;

      try {
        await supabase.from('swipes').delete().eq('swiper_id', myId);
      } catch (e) {
        debugPrint('Failed to clear Supabase swipes: $e');
      }
      _likedProfiles = [];

      _swipeDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _swipesRemaining = 10;
      await _persistSwipeState();

      await initialize();
    } catch (e) {
      debugPrint('Failed to reset demo profiles: $e');
    }
  }
}
