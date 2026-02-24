import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';
import 'package:panda_dating_app/utils/seeded_identity.dart';

class AuthService extends ChangeNotifier {
static const _premiumKey = 'is_premium_v1';
static const _premiumUntilKey = 'premium_until_v1';
static const _notificationsKey = 'notifications_v1';
static const _demoUserKey = 'demo_user_v1';

StreamSubscription<supa.AuthState>? _authStateSub;

User? _currentUser;
bool _isAuthenticated = false;
bool _isLoading = false;
bool _isPremium = false;
DateTime? _premiumUntil;
List<String> _notifications = const [];

User? get currentUser => _currentUser;
bool get isAuthenticated => _isAuthenticated;
bool get isLoading => _isLoading;
bool get isPremium => _isPremium;
DateTime? get premiumUntil => _premiumUntil;
List<String> get notifications => _notifications;
int get unreadNotificationsCount => _notifications.length;

Future<void> initialize() async {
_isLoading = true;
notifyListeners();

try {
final prefs = await SharedPreferences.getInstance();
_premiumUntil = DateTime.tryParse(prefs.getString(_premiumUntilKey) ?? '');
_isPremium = _premiumUntil != null ? _premiumUntil!.isAfter(DateTime.now()) : (prefs.getBool(_premiumKey) ?? false);
_notifications = prefs.getStringList(_notificationsKey) ?? _seedNotifications();
if ((prefs.getStringList(_notificationsKey) ?? []).isEmpty) {
await prefs.setStringList(_notificationsKey, _notifications);
}

final supabase = SupabaseBootstrap.client;
if (supabase == null) {
debugPrint('Supabase is not configured; running AuthService in local demo mode.');
final raw = prefs.getString(_demoUserKey);
if (raw != null && raw.trim().isNotEmpty) {
try {
_currentUser = User.fromJson(_decodeUserJson(raw));
_isAuthenticated = true;
} catch (e) {
debugPrint('Failed to restore demo user: $e');
_currentUser = null;
_isAuthenticated = false;
}
} else {
_currentUser = null;
_isAuthenticated = false;
}
return;
}

_authStateSub ??= supabase.auth.onAuthStateChange.listen((data) {
_refreshFromSession(data.session);
});

await _refreshFromSession(supabase.auth.currentSession);
await refreshPremiumFromServer();
} catch (e) {
debugPrint('Failed to initialize auth: $e');
} finally {
_isLoading = false;
notifyListeners();
}
}

Future<void> _refreshFromSession(supa.Session? session) async {
try {
final supabase = SupabaseBootstrap.client;
if (supabase == null) return;

final supaUser = session?.user;
if (supaUser == null) {
_currentUser = null;
_isAuthenticated = false;
notifyListeners();
return;
}

_isAuthenticated = true;

try {
final data = await supabase.from('profiles').select().eq('id', supaUser.id).maybeSingle();
if (data != null) {
_currentUser = User.fromJson(_profileRowToUserJson(data, supaUserId: supaUser.id, email: supaUser.email));
} else {
_currentUser = _sessionUserFallback(supaUser.id, supaUser.email);
}
} catch (e) {
debugPrint('Supabase profile fetch failed during auth refresh: $e');
_currentUser = _sessionUserFallback(supaUser.id, supaUser.email);
}

notifyListeners();
} catch (e) {
debugPrint('Auth refresh failed: $e');
}
}

Map<String, dynamic> _profileRowToUserJson(Map<String, dynamic> row, {required String supaUserId, required String? email}) {
final now = DateTime.now();
return {
'id': supaUserId,
'name': row['name'] ?? (email?.split('@').first ?? 'Panda User'),
'age': row['age'] ?? 24,
'bio': row['bio'] ?? 'New to Panda! 🐼',
'location': row['location'] ?? 'Location not set',
'city': row['city'],
'country': row['country'],
'profession': row['profession'],
'tribe': row['tribe'],
'characterName': row['character_name'],
'generationPlatform': row['generation_platform'],
'seedNumber': row['seed_number'],
'identityCreatedAt': row['identity_created_at'],
'identityNotes': row['identity_notes'],
'phone': row['phone'],
'dateOfBirth': row['date_of_birth'],
'photos': (row['photos'] as List?)?.cast<String>() ?? const <String>[],
'interests': (row['interests'] as List?)?.cast<String>() ?? const <String>[],
'gender': row['gender'] ?? 'Not specified',
'lookingFor': row['looking_for'] ?? 'Not specified',
'createdAt': row['created_at'] ?? now.toIso8601String(),
'updatedAt': row['updated_at'] ?? now.toIso8601String(),
};
}

User _sessionUserFallback(String id, String? email) {
final now = DateTime.now();
final name = (email?.split('@').first ?? 'Panda User');
return User(
id: id,
name: name.isEmpty ? 'Panda User' : name,
age: 24,
bio: 'Signed in with Supabase ✨',
location: 'Location not set',
city: null,
country: null,
profession: null,
tribe: null,
phone: null,
dateOfBirth: null,
photos: const [],
interests: const [],
gender: 'Not specified',
lookingFor: 'Not specified',
createdAt: now,
updatedAt: now,
);
}

List<String> _seedNotifications() => [
'Welcome to Panda 🐼 — complete your profile for better matches.',
'Tip: Add at least 3 interests to improve suggestions.',
];

Future<void> setPremium(bool value) async {
_premiumUntil = value ? DateTime.now().add(const Duration(days: 30)) : null;
_isPremium = value;
notifyListeners();
try {
final prefs = await SharedPreferences.getInstance();
await prefs.setBool(_premiumKey, value);
await prefs.setString(_premiumUntilKey, _premiumUntil?.toIso8601String() ?? '');
} catch (e) {
debugPrint('Failed to persist premium: $e');
}
}

Future<void> refreshPremiumFromServer() async {
try {
final supabase = SupabaseBootstrap.client;
final userId = supabase?.auth.currentUser?.id;
if (supabase == null || userId == null) return;

final row = await supabase.from('profiles').select('premium_until').eq('id', userId).maybeSingle();
final raw = row?['premium_until'];
final parsed = raw == null ? null : DateTime.tryParse(raw.toString());

_premiumUntil = parsed;
_isPremium = parsed != null && parsed.isAfter(DateTime.now());
notifyListeners();

try {
final prefs = await SharedPreferences.getInstance();
await prefs.setString(_premiumUntilKey, _premiumUntil?.toIso8601String() ?? '');
await prefs.setBool(_premiumKey, _isPremium);
} catch (e) {
debugPrint('Failed to persist premium_until: $e');
}
} catch (e) {
// If the column doesn't exist yet (or RLS blocks it), keep local fallback.
debugPrint('refreshPremiumFromServer failed (safe to ignore until DB is migrated): $e');
}
}

Future<void> clearNotifications() async {
_notifications = const [];
notifyListeners();
try {
final prefs = await SharedPreferences.getInstance();
await prefs.setStringList(_notificationsKey, const []);
} catch (e) {
debugPrint('Failed to clear notifications: $e');
}
}

Future<bool> signIn(String email, String password) async {
_isLoading = true;
notifyListeners();

try {
final supabase = SupabaseBootstrap.client;
if (supabase == null) {
final ok = await continueAsGuest();
final nameFromEmail = email.trim().split('@').first;
if (_currentUser != null && nameFromEmail.isNotEmpty) {
_currentUser = _currentUser!.copyWith(name: nameFromEmail, updatedAt: DateTime.now());
await _persistDemoUser(_currentUser);
}
return ok;
}

final res = await supabase.auth.signInWithPassword(email: email.trim(), password: password);
final supaUser = res.user;
if (supaUser == null) throw Exception('Supabase sign-in succeeded but returned null user.');

User user;
try {
final row = await supabase.from('profiles').select().eq('id', supaUser.id).maybeSingle();
if (row != null) {
user = User.fromJson(_profileRowToUserJson(row, supaUserId: supaUser.id, email: supaUser.email));
} else {
user = _sessionUserFallback(supaUser.id, supaUser.email);
}
} catch (e) {
debugPrint('Supabase profile fetch failed during signIn: $e');
user = _sessionUserFallback(supaUser.id, supaUser.email);
}

_currentUser = user;
_isAuthenticated = true;
return true;
} catch (e) {
debugPrint('Sign in failed: $e');
return false;
} finally {
_isLoading = false;
notifyListeners();
}
}

Future<bool> signUp({required String email, required String password, required String name, required int age, String? phone}) async {
_isLoading = true;
notifyListeners();

try {
final supabase = SupabaseBootstrap.client;
if (supabase == null) {
final ok = await continueAsGuest();
if (_currentUser != null) {
final fallback = email.trim().split('@').first;
_currentUser = _currentUser!.copyWith(
name: name.trim().isNotEmpty ? name.trim() : (fallback.isNotEmpty ? fallback : _currentUser!.name),
age: age,
phone: phone?.trim().isEmpty == true ? null : phone,
updatedAt: DateTime.now(),
);
await _persistDemoUser(_currentUser);
}
return ok;
}

final res = await supabase.auth.signUp(email: email.trim(), password: password);
final supaUser = res.user;
if (supaUser == null) throw Exception('Supabase sign-up succeeded but returned null user.');

final now = DateTime.now();
final user = User(
id: supaUser.id,
name: name.trim().isEmpty ? (email.split('@').first) : name.trim(),
age: age,
bio: 'New to Panda! 🐼',
location: 'Location not set',
city: null,
country: null,
profession: null,
tribe: null,
phone: phone?.trim().isEmpty == true ? null : phone,
dateOfBirth: null,
photos: const [],
interests: const [],
gender: 'Not specified',
lookingFor: 'Not specified',
createdAt: now,
updatedAt: now,
);

try {
await supabase.from('profiles').upsert({
'id': supaUser.id,
'name': user.name,
'age': user.age,
'bio': user.bio,
'location': user.location,
'phone': user.phone,
'photos': user.photos,
'interests': user.interests,
'gender': user.gender,
'looking_for': user.lookingFor,
'character_name': user.characterName,
'generation_platform': user.generationPlatform,
'seed_number': user.seedNumber,
'identity_created_at': user.identityCreatedAt?.toIso8601String(),
'identity_notes': user.identityNotes,
'created_at': user.createdAt.toIso8601String(),
'updated_at': user.updatedAt.toIso8601String(),
});
} catch (e) {
debugPrint('Supabase profile upsert failed during signUp: $e');
}

_currentUser = user;
_isAuthenticated = true;
return true;
} catch (e) {
debugPrint('Sign up failed: $e');
return false;
} finally {
_isLoading = false;
notifyListeners();
}
}

Map<String, dynamic> _decodeUserJson(String raw) {
final decoded = jsonDecode(raw);
if (decoded is! Map<String, dynamic>) throw FormatException('Invalid user json');
return decoded;
}

Future<void> _persistDemoUser(User? user) async {
try {
final prefs = await SharedPreferences.getInstance();
if (user == null) {
await prefs.remove(_demoUserKey);
} else {
await prefs.setString(_demoUserKey, jsonEncode(user.toJson()));
}
} catch (e) {
debugPrint('Failed to persist demo user: $e');
}
}

Future<bool> continueAsGuest() async {
_isLoading = true;
notifyListeners();

try {
final now = DateTime.now();
final identity = SeededIdentity.build(seed: SeededIdentity.lockedBaseSeed, personId: 'demo_user', photosPerProfile: 3);

final user = User(
id: 'demo_user',
name: identity.name,
age: identity.age,
bio: identity.bio,
location: identity.location,
city: identity.city,
country: identity.country,
profession: identity.profession,
tribe: null,
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

_currentUser = user;
_isAuthenticated = true;
await _persistDemoUser(user);
return true;
} catch (e) {
debugPrint('Failed to enter demo mode: $e');
return false;
} finally {
_isLoading = false;
notifyListeners();
}
}

Future<void> signOut() async {
try {
final supabase = SupabaseBootstrap.client;
if (supabase != null) await supabase.auth.signOut();
_currentUser = null;
_isAuthenticated = false;
await _persistDemoUser(null);
notifyListeners();
} catch (e) {
debugPrint('Sign out failed: $e');
}
}

Future<bool> signInWithGoogle() async {
_isLoading = true;
notifyListeners();

try {
final supabase = SupabaseBootstrap.client;
if (supabase == null) {
final ok = await continueAsGuest();
if (_currentUser != null) {
_currentUser = _currentUser!.copyWith(name: 'Google Panda', updatedAt: DateTime.now());
await _persistDemoUser(_currentUser);
}
return ok;
}

final redirectTo = kIsWeb ? Uri.base.origin : 'io.supabase.flutter://login-callback/';
await supabase.auth.signInWithOAuth(
supa.OAuthProvider.google,
redirectTo: redirectTo,
scopes: 'email profile',
);
return true;
} catch (e) {
debugPrint('Google sign-in failed: $e');
return false;
} finally {
_isLoading = false;
notifyListeners();
}
}

@override
void dispose() {
_authStateSub?.cancel();
super.dispose();
}

Future<void> updateProfile(User user) async {
try {
final supabase = SupabaseBootstrap.client;
final sessionUserId = supabase?.auth.currentUser?.id;
if (supabase != null && sessionUserId != null && sessionUserId == user.id) {
try {
await supabase.from('profiles').upsert({
'id': user.id,
'name': user.name,
'age': user.age,
'bio': user.bio,
'location': user.location,
'city': user.city,
'country': user.country,
'profession': user.profession,
'tribe': user.tribe,
'character_name': user.characterName,
'generation_platform': user.generationPlatform,
'seed_number': user.seedNumber,
'identity_created_at': user.identityCreatedAt?.toIso8601String(),
'identity_notes': user.identityNotes,
'phone': user.phone,
'date_of_birth': user.dateOfBirth?.toIso8601String(),
'photos': user.photos,
'interests': user.interests,
'gender': user.gender,
'looking_for': user.lookingFor,
'updated_at': DateTime.now().toIso8601String(),
});
} catch (e) {
debugPrint('Supabase profile upsert failed during updateProfile: $e');
}
} else {
debugPrint('updateProfile called without a matching Supabase session; ignoring remote write.');
}

_currentUser = user;
notifyListeners();
} catch (e) {
debugPrint('Profile update failed: $e');
}
}
}
