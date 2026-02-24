import 'package:flutter/material.dart';
import 'package:panda_dating_app/screens/discovery_screen.dart';
import 'package:panda_dating_app/screens/matches_screen.dart';
import 'package:panda_dating_app/screens/profile_screen.dart';
import 'package:panda_dating_app/screens/events_screen.dart';
import 'package:panda_dating_app/screens/live_rooms_screen.dart';
import 'package:panda_dating_app/theme.dart';

class HomeScreen extends StatefulWidget {
const HomeScreen({super.key});

@override
State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
int _currentIndex = 0;

final List<Widget> _screens = const [
DiscoveryScreen(),
MatchesScreen(),
EventsScreen(),
LiveRoomsScreen(),
ProfileScreen(),
];

@override
Widget build(BuildContext context) {
return Scaffold(
body: _screens[_currentIndex],
bottomNavigationBar: Container(
decoration: BoxDecoration(
color: PandaColors.bgCard,
border: Border(
top: BorderSide(
color: PandaColors.borderColor.withValues(alpha: 0.3),
width: 1,
),
),
),
child: SafeArea(
child: Padding(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
child: Row(
children: [
Expanded(flex: _currentIndex == 0 ? 2 : 1, child: _buildNavItem(Icons.explore, 'Discover', 0)),
Expanded(flex: _currentIndex == 1 ? 2 : 1, child: _buildNavItem(Icons.favorite, 'Matches', 1)),
Expanded(flex: _currentIndex == 2 ? 2 : 1, child: _buildNavItem(Icons.event, 'Events', 2)),
Expanded(flex: _currentIndex == 3 ? 2 : 1, child: _buildNavItem(Icons.podcasts, 'Live', 3)),
Expanded(flex: _currentIndex == 4 ? 2 : 1, child: _buildNavItem(Icons.person, 'Profile', 4)),
],
),
),
),
),
);
}

Widget _buildNavItem(IconData icon, String label, int index) {
final isActive = _currentIndex == index;

return Semantics(
button: true,
selected: isActive,
label: label,
child: GestureDetector(
onTap: () => setState(() => _currentIndex = index),
behavior: HitTestBehavior.opaque,
child: Center(
child: AnimatedContainer(
duration: const Duration(milliseconds: 220),
curve: Curves.easeOutCubic,
padding: EdgeInsets.symmetric(horizontal: isActive ? 12 : 8, vertical: 10),
decoration: BoxDecoration(
gradient: isActive ? PandaColors.gradientButton : null,
borderRadius: BorderRadius.circular(AppRadius.full),
boxShadow: isActive
? [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 6))]
: null,
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(icon, color: isActive ? Colors.white : PandaColors.textMuted, size: 22),
if (isActive) ...[
const SizedBox(width: 6),
ConstrainedBox(
constraints: const BoxConstraints(maxWidth: 74),
child: Text(
label,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
),
),
],
],
),
),
),
),
);
}
}
