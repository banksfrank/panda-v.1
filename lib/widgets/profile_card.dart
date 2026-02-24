import 'package:flutter/material.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/theme.dart';

class ProfileCard extends StatefulWidget {
final User user;
final bool isTopCard;
final VoidCallback onSwipeLeft;
final VoidCallback onSwipeRight;

const ProfileCard({
super.key,
required this.user,
required this.isTopCard,
required this.onSwipeLeft,
required this.onSwipeRight,
});

@override
State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> with SingleTickerProviderStateMixin {
late AnimationController _controller;
late Animation<Offset> _offsetAnimation;
late Animation<double> _rotationAnimation;
Offset _dragOffset = Offset.zero;
bool _isDragging = false;

@override
void initState() {
super.initState();
_controller = AnimationController(
vsync: this,
duration: const Duration(milliseconds: 300),
);
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

void _onPanStart(DragStartDetails details) {
if (!widget.isTopCard) return;
setState(() => _isDragging = true);
}

void _onPanUpdate(DragUpdateDetails details) {
if (!widget.isTopCard) return;
setState(() => _dragOffset += details.delta);
}

void _onPanEnd(DragEndDetails details) {
if (!widget.isTopCard) return;

const swipeThreshold = 100.0;

if (_dragOffset.dx > swipeThreshold) {
_animateSwipe(true);
} else if (_dragOffset.dx < -swipeThreshold) {
_animateSwipe(false);
} else {
setState(() {
_dragOffset = Offset.zero;
_isDragging = false;
});
}
}

void _animateSwipe(bool isRight) {
_offsetAnimation = Tween<Offset>(
begin: _dragOffset,
end: Offset(isRight ? 500 : -500, _dragOffset.dy),
).animate(_controller);

_controller.forward().then((_) {
if (isRight) {
widget.onSwipeRight();
} else {
widget.onSwipeLeft();
}
_controller.reset();
setState(() {
_dragOffset = Offset.zero;
_isDragging = false;
});
});
}

@override
Widget build(BuildContext context) {
final screenWidth = MediaQuery.of(context).size.width;
final rotation = _dragOffset.dx / screenWidth * 0.4;

return GestureDetector(
onPanStart: _onPanStart,
onPanUpdate: _onPanUpdate,
onPanEnd: _onPanEnd,
child: AnimatedBuilder(
animation: _controller,
builder: (context, child) {
final offset = _controller.isAnimating ? _offsetAnimation.value : _dragOffset;

return Transform.translate(
offset: offset,
child: Transform.rotate(
angle: rotation,
child: child,
),
);
},
child: Padding(
padding: const EdgeInsets.all(16),
child: Stack(
children: [
_buildCard(),
if (_isDragging) _buildSwipeIndicator(),
Positioned(
bottom: 16,
left: 0,
right: 0,
child: _buildActionButtons(),
),
],
),
),
),
);
}

Widget _buildCard() {
return Container(
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(AppRadius.xl),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.3),
blurRadius: 30,
offset: const Offset(0, 10),
),
],
),
child: ClipRRect(
borderRadius: BorderRadius.circular(AppRadius.xl),
child: Stack(
fit: StackFit.expand,
children: [
Image.network(
widget.user.photos.isNotEmpty
? widget.user.photos[0]
: 'https://images.unsplash.com/photo-1511367461989-f85a21fda167?w=400',
fit: BoxFit.cover,
errorBuilder: (context, error, stackTrace) => Container(
color: PandaColors.bgCard,
child: const Center(
child: Icon(Icons.person, size: 100, color: PandaColors.textMuted),
),
),
),
Container(
decoration: BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topCenter,
end: Alignment.bottomCenter,
colors: [
Colors.transparent,
Colors.black.withValues(alpha: 0.8),
],
stops: const [0.5, 1.0],
),
),
),
Positioned(
bottom: 80,
left: 24,
right: 24,
child: _buildUserInfo(),
),
],
),
),
);
}

Widget _buildUserInfo() {
return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
children: [
Expanded(
child: Text(
'${widget.user.name}, ${widget.user.age}',
style: const TextStyle(
color: Colors.white,
fontSize: 32,
fontWeight: FontWeight.w700,
),
),
),
],
),
const SizedBox(height: 4),
Row(
children: [
const Icon(Icons.location_on, color: Colors.white70, size: 18),
const SizedBox(width: 4),
Text(
widget.user.location,
style: const TextStyle(
color: Colors.white70,
fontSize: 16,
),
),
],
),
const SizedBox(height: 12),
Text(
widget.user.bio,
style: const TextStyle(
color: Colors.white,
fontSize: 16,
),
maxLines: 2,
overflow: TextOverflow.ellipsis,
),
const SizedBox(height: 12),
Wrap(
spacing: 8,
runSpacing: 8,
children: widget.user.interests.take(3).map((interest) => Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.2),
borderRadius: BorderRadius.circular(AppRadius.full),
border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
),
child: Text(
interest,
style: const TextStyle(
color: Colors.white,
fontSize: 13,
fontWeight: FontWeight.w500,
),
),
)).toList(),
),
],
);
}

Widget _buildActionButtons() {
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 40),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceEvenly,
children: [
_buildActionButton(
icon: Icons.close,
color: PandaColors.danger,
onTap: () => _animateSwipe(false),
),
_buildActionButton(
icon: Icons.favorite,
color: PandaColors.pink,
onTap: () => _animateSwipe(true),
isLarge: true,
),
_buildActionButton(
icon: Icons.star,
color: PandaColors.peachDark,
onTap: () {},
),
],
),
);
}

Widget _buildActionButton({
required IconData icon,
required Color color,
required VoidCallback onTap,
bool isLarge = false,
}) {
final size = isLarge ? 64.0 : 56.0;
final iconSize = isLarge ? 32.0 : 28.0;

return GestureDetector(
onTap: widget.isTopCard ? onTap : null,
child: Container(
width: size,
height: size,
decoration: BoxDecoration(
color: Colors.white,
shape: BoxShape.circle,
boxShadow: [
BoxShadow(
color: color.withValues(alpha: 0.3),
blurRadius: 20,
offset: const Offset(0, 4),
),
],
),
child: Icon(icon, color: color, size: iconSize),
),
);
}

Widget _buildSwipeIndicator() {
final isRight = _dragOffset.dx > 0;

return Positioned(
top: 100,
left: isRight ? null : 40,
right: isRight ? 40 : null,
child: Transform.rotate(
angle: isRight ? -0.3 : 0.3,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
decoration: BoxDecoration(
border: Border.all(
color: isRight ? PandaColors.success : PandaColors.danger,
width: 4,
),
borderRadius: BorderRadius.circular(AppRadius.md),
),
child: Text(
isRight ? 'LIKE' : 'NOPE',
style: TextStyle(
color: isRight ? PandaColors.success : PandaColors.danger,
fontSize: 36,
fontWeight: FontWeight.w900,
letterSpacing: 2,
),
),
),
),
);
}
}
