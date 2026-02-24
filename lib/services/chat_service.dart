import 'package:flutter/foundation.dart';
import 'package:panda_dating_app/models/message.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';

class ChatService extends ChangeNotifier {
  Map<String, List<Message>> _conversations = {};
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  String? get myUserId => SupabaseBootstrap.client?.auth.currentUser?.id ?? 'demo_user';

  List<Message> getConversation(String userId) => _conversations[userId] ?? [];

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final supabase = SupabaseBootstrap.client;
      if (supabase == null) {
        _conversations = _seedDemoConversations();
      } else {
        // Supabase-backed: conversations load on-demand.
        _conversations = {};
      }
    } catch (e) {
      debugPrint('Failed to initialize chat: $e');
      _conversations = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, List<Message>> _seedDemoConversations() {
    final now = DateTime.now();
    return {
      'demo_match_1': [
        Message(id: 'm1', senderId: 'demo_match_1', receiverId: 'demo_user', text: 'Hey! I saw you like coffee ☕', sentAt: now.subtract(const Duration(hours: 20)), isRead: true),
        Message(id: 'm2', senderId: 'demo_user', receiverId: 'demo_match_1', text: 'Absolutely. What’s your go-to order?', sentAt: now.subtract(const Duration(hours: 19, minutes: 30)), isRead: true),
        Message(id: 'm3', senderId: 'demo_match_1', receiverId: 'demo_user', text: 'I’m a cappuccino person. You?', sentAt: now.subtract(const Duration(hours: 19)), isRead: true),
      ],
      'demo_match_2': [
        Message(id: 'm4', senderId: 'demo_match_2', receiverId: 'demo_user', text: 'Weekend hike or live music first?', sentAt: now.subtract(const Duration(days: 1, hours: 2)), isRead: true),
      ],
    };
  }

  Future<void> loadConversation(String otherUserId) async {
    final supabase = SupabaseBootstrap.client;
    final me = supabase?.auth.currentUser?.id;
    if (supabase == null || me == null) {
      _conversations.putIfAbsent(otherUserId, () => _conversations[otherUserId] ?? []);
      notifyListeners();
      return;
    }

    try {
      final rows = await supabase
          .from('direct_messages')
          .select('id,sender_id,receiver_id,body,created_at,read_at')
          .or('and(sender_id.eq.$me,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$me)')
          .order('created_at');

      _conversations[otherUserId] = (rows as List).map((r) {
        DateTime parse(dynamic v) {
          if (v is DateTime) return v;
          return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
        }

        return Message(
          id: (r['id'] ?? '').toString(),
          senderId: (r['sender_id'] ?? '').toString(),
          receiverId: (r['receiver_id'] ?? '').toString(),
          text: (r['body'] ?? '').toString(),
          sentAt: parse(r['created_at']),
          isRead: r['read_at'] != null,
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load Supabase conversation: $e');
    }
  }

  Future<void> sendMessage(String receiverId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final supabase = SupabaseBootstrap.client;
    final me = supabase?.auth.currentUser?.id;
    if (supabase == null || me == null) {
      final msg = Message(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        senderId: myUserId ?? 'demo_user',
        receiverId: receiverId,
        text: trimmed,
        sentAt: DateTime.now(),
        isRead: true,
      );
      _conversations.putIfAbsent(receiverId, () => []).add(msg);
      notifyListeners();
      return;
    }

    try {
      final inserted = await supabase
          .from('direct_messages')
          .insert({'sender_id': me, 'receiver_id': receiverId, 'body': trimmed})
          .select('id,sender_id,receiver_id,body,created_at,read_at')
          .single();

      final createdAt = inserted['created_at'];
      final msg = Message(
        id: (inserted['id'] ?? '').toString(),
        senderId: (inserted['sender_id'] ?? '').toString(),
        receiverId: (inserted['receiver_id'] ?? '').toString(),
        text: (inserted['body'] ?? '').toString(),
        sentAt: (createdAt is DateTime) ? createdAt : DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now(),
        isRead: inserted['read_at'] != null,
      );

      _conversations.putIfAbsent(receiverId, () => []).add(msg);
      notifyListeners();
    } catch (e) {
      debugPrint('Supabase sendMessage failed: $e');
    }
  }
}
