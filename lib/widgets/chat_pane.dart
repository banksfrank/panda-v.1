import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/services/chat_service.dart';
import 'package:panda_dating_app/theme.dart';

/// Reusable chat pane that shows a conversation thread and an input field.
/// Use inside full-screen chat or as a side preview.
class ChatPane extends StatefulWidget {
  final User otherUser;

  const ChatPane({super.key, required this.otherUser});

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = context.read<ChatService>();
      await service.initialize();
      await service.loadConversation(widget.otherUser.id);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final text = _messageController.text;
    _messageController.clear();
    await context.read<ChatService>().sendMessage(widget.otherUser.id, text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildMessagesList()),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Consumer<ChatService>(
      builder: (context, service, child) {
        final messages = service.getConversation(widget.otherUser.id);

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👋', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                Text(
                  'Say hello to ${widget.otherUser.name}!',
                  style: const TextStyle(
                    color: PandaColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == service.myUserId;
            return _buildMessageBubble(message.text, isMe, message.sentAt);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, DateTime time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: PandaColors.bgCard,
              ),
              child: const Icon(Icons.person, size: 16, color: PandaColors.textMuted),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe ? PandaColors.gradientButton : null,
                    color: isMe ? null : PandaColors.bgCard,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: isMe
                        ? null
                        : Border.all(color: PandaColors.borderColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : PandaColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(time),
                  style: const TextStyle(color: PandaColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PandaColors.bgCard,
        border: Border(
          top: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: PandaColors.bgInput,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: PandaColors.borderColor),
                ),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: PandaColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: PandaColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: PandaColors.gradientButton,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PandaColors.pink.withValues(alpha: 0.3),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
