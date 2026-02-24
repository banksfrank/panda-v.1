import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/widgets/chat_pane.dart';

class ChatScreen extends StatefulWidget {
  final User otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: PandaColors.bgPrimary,
          appBar: AppBar(
            backgroundColor: PandaColors.bgCard,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: PandaColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(
                        widget.otherUser.photos.isNotEmpty
                            ? widget.otherUser.photos[0]
                            : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=400',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.name,
                      style: const TextStyle(
                        color: PandaColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'Online',
                      style: TextStyle(color: PandaColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: isWide
              ? Row(
                  children: [
                    Expanded(child: ChatPane(otherUser: widget.otherUser)),
                    _RightDetailsPanel(user: widget.otherUser),
                  ],
                )
              : ChatPane(otherUser: widget.otherUser),
        );
      },
    );
  }
}

class _RightDetailsPanel extends StatelessWidget {
  final User user;
  const _RightDetailsPanel({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: PandaColors.bgCard,
        border: Border(
          left: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Match', style: Theme.of(context).textTheme.titleLarge?.withColor(PandaColors.textPrimary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PandaColors.bgPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage(
                            user.photos.isNotEmpty
                                ? user.photos[0]
                                : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=400',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(color: PandaColors.textPrimary, fontWeight: FontWeight.w700)),
                        const Text('Online', style: TextStyle(color: PandaColors.textMuted, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.phone, color: PandaColors.textPrimary),
                      tooltip: 'Voice call',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Block'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

