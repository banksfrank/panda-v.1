import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/services/discovery_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/widgets/panda_app_header.dart';
import 'package:panda_dating_app/widgets/panda_sheets.dart';
import 'package:panda_dating_app/widgets/profile_card.dart';

class DiscoveryScreen extends StatefulWidget {
const DiscoveryScreen({super.key});

@override
State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
@override
void initState() {
super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) {
context.read<DiscoveryService>().initialize();
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
body: Container(
decoration: const BoxDecoration(
gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PandaColors.bgPrimary, PandaColors.bgSecondary]),
),
child: SafeArea(
child: Column(
children: [
PandaAppHeader(
showFilters: true,
onTapFilters: () => DiscoveryFilterSheet.show(context),
onTapAi: () => AiAssistantSheet.show(context),
onTapNotifications: () => NotificationsSheet.show(context),
onTapPremium: () => PremiumSheet.show(context),
),
_SwipeCounterBar(
onTapPremium: () => PremiumSheet.show(context),
),
Expanded(child: _ProfileStack(onOutOfSwipes: () => PremiumSheet.show(context))),
],
),
),
),
);
}
}

class _SwipeCounterBar extends StatelessWidget {
final VoidCallback onTapPremium;
const _SwipeCounterBar({required this.onTapPremium});

@override
Widget build(BuildContext context) {
final remaining = context.select<DiscoveryService, int>((s) => s.swipesRemaining);
final isPremium = context.select<AuthService, bool>((s) => s.isPremium);

return Padding(
padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
decoration: BoxDecoration(
color: PandaColors.bgCard,
borderRadius: BorderRadius.circular(AppRadius.lg),
border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.6)),
),
child: Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Icon(Icons.local_fire_department_rounded, color: PandaColors.pink, size: 18),
const SizedBox(width: 8),
Text(isPremium ? 'Unlimited swipes' : '$remaining swipes remaining today', style: const TextStyle(color: PandaColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
if (!isPremium) ...[
const SizedBox(width: 10),
GestureDetector(
onTap: onTapPremium,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
decoration: BoxDecoration(
gradient: PandaColors.gradientGold,
borderRadius: BorderRadius.circular(AppRadius.full),
),
child: Row(
children: const [
Icon(Icons.workspace_premium, color: Colors.black, size: 14),
SizedBox(width: 6),
Text('Unlimited', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
],
),
),
),
]
],
),
),
);
}
}

class _ProfileStack extends StatelessWidget {
final VoidCallback onOutOfSwipes;
const _ProfileStack({required this.onOutOfSwipes});

@override
Widget build(BuildContext context) {
return Consumer2<DiscoveryService, AuthService>(
builder: (context, discovery, auth, _) {
if (discovery.isLoading) {
return const Center(child: CircularProgressIndicator(color: PandaColors.pink));
}

if (discovery.availableProfiles.isEmpty) {
return _EmptyState(onRefresh: discovery.reset, onResetDemo: discovery.resetDemo);
}

Future<void> guardedLike(String id) async {
if (!discovery.canSwipe(isPremium: auth.isPremium)) {
onOutOfSwipes();
return;
}
await discovery.likeProfile(id, isPremium: auth.isPremium);
}

Future<void> guardedPass(String id) async {
if (!discovery.canSwipe(isPremium: auth.isPremium)) {
onOutOfSwipes();
return;
}
await discovery.passProfile(id, isPremium: auth.isPremium);
}

return Stack(
children: [
for (int i = discovery.availableProfiles.length - 1; i >= 0; i--)
if (i < 3)
Positioned.fill(
top: i * 10.0,
child: ProfileCard(
user: discovery.availableProfiles[i],
isTopCard: i == 0,
onSwipeLeft: () => guardedPass(discovery.availableProfiles[i].id),
onSwipeRight: () => guardedLike(discovery.availableProfiles[i].id),
),
),
],
);
},
);
}
}

class _EmptyState extends StatelessWidget {
final VoidCallback onRefresh;
final Future<void> Function() onResetDemo;
const _EmptyState({required this.onRefresh, required this.onResetDemo});

@override
Widget build(BuildContext context) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
const Text('🐼', style: TextStyle(fontSize: 64)),
const SizedBox(height: 16),
const Text('No more profiles', style: TextStyle(color: PandaColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
const SizedBox(height: 8),
const Text('Check back later or expand your filters.', style: TextStyle(color: PandaColors.textMuted)),
const SizedBox(height: 18),
Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
ElevatedButton(
onPressed: onRefresh,
style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
child: Ink(
decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
child: const Padding(
padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
child: Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
),
),
),
const SizedBox(width: 12),
OutlinedButton.icon(
onPressed: () async => onResetDemo(),
icon: const Icon(Icons.refresh_rounded, color: PandaColors.textSecondary, size: 18),
label: const Text('Reset feed', style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w900)),
style: OutlinedButton.styleFrom(
side: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.6)),
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
backgroundColor: PandaColors.bgCard,
),
),
],
),
],
),
),
);
}
}
