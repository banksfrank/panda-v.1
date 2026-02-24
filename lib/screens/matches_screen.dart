import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/services/match_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:intl/intl.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/widgets/chat_pane.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  User? _selectedUser;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PandaColors.bgPrimary, PandaColors.bgSecondary],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return Column(
                children: [
                  _buildAppBar(isWide: isWide),
                  Expanded(
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(child: _buildMatchesList(isWide: isWide)),
                              const SizedBox(width: 12),
                              _buildChatPreviewPanel(),
                            ],
                          )
                        : _buildMatchesList(isWide: isWide),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar({required bool isWide}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => PandaColors.gradientPrimary.createShader(bounds),
            child: const Text(
              'Matches',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const Spacer(),
          if (isWide) _buildOpenChatButton(),
        ],
      ),
    );
  }

  Widget _buildMatchesList({required bool isWide}) {
    return Consumer<MatchService>(
      builder: (context, service, child) {
        if (service.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: PandaColors.pink),
          );
        }

        if (service.matches.isEmpty) {
          return _buildEmptyState(isWide: isWide);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: service.matches.length,
          itemBuilder: (context, index) {
            final match = service.matches[index];
            return _buildMatchCard(match, isWide: isWide);
          },
        );
      },
    );
  }

  Widget _buildMatchCard(match, {required bool isWide}) {
    final timeAgo = _getTimeAgo(match.lastMessageTime ?? match.matchedAt);
    
    return GestureDetector(
      onTap: () {
        if (isWide) {
          setState(() => _selectedUser = match.user);
        } else {
          context.push('/chat/${match.user.id}', extra: match.user);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PandaColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: PandaColors.borderColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(
                        match.user.photos.isNotEmpty
                            ? match.user.photos[0]
                            : 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=400',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (!match.isRead)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: PandaColors.pink,
                        shape: BoxShape.circle,
                        border: Border.all(color: PandaColors.bgCard, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.user.name,
                          style: const TextStyle(
                            color: PandaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          color: PandaColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match.lastMessage ?? 'New match! Say hi 👋',
                    style: TextStyle(
                      color: match.isRead ? PandaColors.textMuted : PandaColors.textSecondary,
                      fontSize: 14,
                      fontWeight: match.isRead ? FontWeight.w400 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Open chat',
                  onPressed: () => context.push('/chat/${match.user.id}', extra: match.user),
                  icon: const Icon(Icons.comment, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Unmatch',
                  onPressed: () => context.read<MatchService>().removeMatch(match.id),
                  icon: const Icon(Icons.person_off, color: Colors.redAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isWide}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('💔', style: TextStyle(fontSize: 80)),
          SizedBox(height: 24),
          Text(
            'No matches yet',
            style: TextStyle(
              color: PandaColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start swiping to find your match!',
            style: TextStyle(
              color: PandaColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreviewPanel() {
    if (_selectedUser == null) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PandaColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.3)),
          ),
          child: const Center(
            child: Text(
              'Select a match to view the conversation',
              style: TextStyle(color: PandaColors.textMuted),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: PandaColors.bgPrimary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.3)),
        ),
        child: ChatPane(otherUser: _selectedUser!),
      ),
    );
  }

  Widget _buildOpenChatButton() {
    return Consumer<MatchService>(
      builder: (context, service, _) {
        return GestureDetector(
          onTap: () {
            if (service.matches.isEmpty) return;
            final latest = [...service.matches]
              ..sort((a, b) {
                final at = a.lastMessageTime ?? a.matchedAt;
                final bt = b.lastMessageTime ?? b.matchedAt;
                return bt.compareTo(at);
              });
            final user = latest.first.user;
            context.push('/chat/${user.id}', extra: user);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: PandaColors.gradientButton,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: [
                BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 12),
              ],
            ),
            child: Row(
              children: const [
                Icon(Icons.comment, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Open Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}
