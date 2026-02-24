import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/theme.dart';

class PandaAppHeader extends StatelessWidget {
  final Widget? title;
  final bool showFilters;
  final VoidCallback? onTapFilters;
  final VoidCallback? onTapAi;
  final VoidCallback? onTapNotifications;
  final VoidCallback? onTapPremium;

  const PandaAppHeader({
    super.key,
    this.title,
    this.showFilters = false,
    this.onTapFilters,
    this.onTapAi,
    this.onTapNotifications,
    this.onTapPremium,
  });

  @override
  Widget build(BuildContext context) {
    final unread = context.select<AuthService, int>((s) => s.unreadNotificationsCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          if (title != null)
            Expanded(child: title!)
          else
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PandaColors.bgCard,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.15), blurRadius: 20)],
                  ),
                  child: const Center(child: Text('🐼', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                ShaderMask(
                  shaderCallback: (bounds) => PandaColors.gradientPrimary.createShader(bounds),
                  child: const Text('Panda', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          const Spacer(),
          if (showFilters)
            _HeaderIconButton(icon: Icons.tune, tooltip: 'Filters', onTap: onTapFilters),
          _HeaderIconButton(icon: Icons.smart_toy_outlined, tooltip: 'AI Assistant', onTap: onTapAi),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _HeaderIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onTap: onTapNotifications),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: PandaColors.gradientButton,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(color: PandaColors.bgPrimary, width: 1.5),
                    ),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          _HeaderIconButton(icon: Icons.workspace_premium, tooltip: 'Premium', onTap: onTapPremium, color: PandaColors.gold),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PandaColors.bgCard,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5)),
          ),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: color ?? PandaColors.textSecondary, size: 20),
          ),
        ),
      ),
    );
  }
}
