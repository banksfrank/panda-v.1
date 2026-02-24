import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/services/match_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/widgets/panda_app_header.dart';
import 'package:panda_dating_app/widgets/panda_sheets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PandaColors.bgPrimary, PandaColors.bgSecondary]),
        ),
        child: SafeArea(
          child: Consumer<AuthService>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              if (user == null) return const Center(child: CircularProgressIndicator(color: PandaColors.pink));

              return SingleChildScrollView(
                child: Column(
                  children: [
                    PandaAppHeader(
                      title: ShaderMask(
                        shaderCallback: (b) => PandaColors.gradientPrimary.createShader(b),
                        child: const Text('Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                      onTapAi: () => AiAssistantSheet.show(context),
                      onTapNotifications: () => NotificationsSheet.show(context),
                      onTapPremium: () => PremiumSheet.show(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ProfileHeaderCard(
                        name: user.name,
                        age: user.age,
                        city: user.city,
                        country: user.country,
                        photoUrl: user.photos.isNotEmpty ? user.photos.first : null,
                        interests: user.interests,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StatsRow(),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _Section(title: 'About', child: Text(user.bio.isEmpty ? 'Tell people about yourself…' : user.bio, style: const TextStyle(color: PandaColors.textSecondary, height: 1.5))),
                    ),
                    if (user.interests.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _Section(
                          title: 'Interests',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: user.interests
                                .map(
                                  (i) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.18), blurRadius: 12)]),
                                    child: Text(i, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _Section(
                        title: 'Details',
                        child: _DetailsGrid(
                          profession: user.profession,
                          tribe: user.tribe,
                          gender: user.gender,
                          lookingFor: user.lookingFor,
                          location: [user.city, user.country].whereType<String>().where((e) => e.trim().isNotEmpty).join(', '),
                        ),
                      ),
                    ),
                    if ([user.characterName, user.generationPlatform, user.seedNumber, user.identityNotes].whereType<String>().any((e) => e.trim().isNotEmpty) || user.identityCreatedAt != null) ...[
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _Section(
                          title: 'Identity (locked)',
                          child: _IdentityMeta(
                            characterName: user.characterName,
                            createdAt: user.identityCreatedAt,
                            platform: user.generationPlatform,
                            seedNumber: user.seedNumber,
                            notes: user.identityNotes,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ActionsGrid(
                        onEditProfile: () => context.go('/onboarding'),
                        onPremium: () => PremiumSheet.show(context),
                        onSettings: () => _snack(context, 'Settings coming soon'),
                        onAdminSeed: kDebugMode ? () => context.push('/admin/seed') : null,
                        onLogout: () async {
                          await auth.signOut();
                          if (context.mounted) context.go('/auth');
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: PandaColors.bgCard));
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final int age;
  final String? city;
  final String? country;
  final String? photoUrl;
  final List<String> interests;

  const _ProfileHeaderCard({required this.name, required this.age, required this.city, required this.country, required this.photoUrl, required this.interests});

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (age > 0) '$age',
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((country ?? '').trim().isNotEmpty) country!.trim(),
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35))),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              gradient: PandaColors.gradientPrimary,
              image: photoUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    ),
            ),
            child: photoUrl == null
                ? const Center(child: Text('🐼', style: TextStyle(fontSize: 56)))
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(meta.isEmpty ? 'Complete your profile' : meta, style: const TextStyle(color: PandaColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests.take(6).map((i) => _Badge(text: i)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
      child: Text(text, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final matches = context.select<MatchService, int>((s) => s.matches.length);

    Widget stat(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35))),
          child: Column(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: PandaColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('Matches', '$matches'),
        const SizedBox(width: 10),
        stat('Likes', '23'),
        const SizedBox(width: 10),
        stat('Views', '104'),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  final String? profession;
  final String? tribe;
  final String gender;
  final String lookingFor;
  final String location;

  const _DetailsGrid({required this.profession, required this.tribe, required this.gender, required this.lookingFor, required this.location});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, String value) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.4))),
        child: Row(
          children: [
            Icon(icon, color: PandaColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: PandaColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final items = <Widget>[
      tile(Icons.work_outline, 'Profession', (profession ?? '').trim().isEmpty ? '—' : profession!.trim()),
      tile(Icons.public, 'Culture / Tribe', (tribe ?? '').trim().isEmpty ? '—' : tribe!.trim()),
      tile(Icons.person_outline, 'Gender', gender),
      tile(Icons.favorite_border, 'Interested in', lookingFor),
      tile(Icons.location_on_outlined, 'Location', location.isEmpty ? '—' : location),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 2 : 1,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: MediaQuery.sizeOf(context).width > 700 ? 3.2 : 3.5,
      children: items,
    );
  }
}

class _IdentityMeta extends StatelessWidget {
  final String? characterName;
  final DateTime? createdAt;
  final String? platform;
  final String? seedNumber;
  final String? notes;

  const _IdentityMeta({required this.characterName, required this.createdAt, required this.platform, required this.seedNumber, required this.notes});

  @override
  Widget build(BuildContext context) {
    String fmtDate(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(label, style: const TextStyle(color: PandaColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.4)),
            ),
          ],
        ),
      );
    }

    final items = <Widget>[];
    if ((characterName ?? '').trim().isNotEmpty) items.add(row('Name', characterName!.trim()));
    if (createdAt != null) items.add(row('Created', fmtDate(createdAt!)));
    if ((platform ?? '').trim().isNotEmpty) items.add(row('Platform', platform!.trim()));
    if ((seedNumber ?? '').trim().isNotEmpty) items.add(row('Seed', seedNumber!.trim()));
    if ((notes ?? '').trim().isNotEmpty) items.add(row('Notes', notes!.trim()));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.isEmpty ? [const Text('—', style: TextStyle(color: PandaColors.textMuted))] : items);
  }
}

class _ActionsGrid extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onPremium;
  final VoidCallback onSettings;
  final VoidCallback? onAdminSeed;
  final VoidCallback onLogout;

  const _ActionsGrid({required this.onEditProfile, required this.onPremium, required this.onSettings, required this.onAdminSeed, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    Widget btn({required IconData icon, required String text, required VoidCallback onTap, bool danger = false, bool gold = false}) {
      final bg = danger ? const LinearGradient(colors: [Color(0xFF3A1120), Color(0xFF2B0B15)]) : null;
      final border = danger ? Colors.redAccent.withValues(alpha: 0.4) : PandaColors.borderColor.withValues(alpha: 0.4);
      final gradient = gold
          ? PandaColors.gradientGold
          : (!danger ? null : bg);

      final child = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: gold ? Colors.black : (danger ? Colors.redAccent : Colors.white), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: gold ? Colors.black : (danger ? Colors.redAccent : Colors.white), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );

      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: gold || danger ? null : PandaColors.bgCard,
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: border),
          ),
          child: child,
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: [
        btn(icon: Icons.edit, text: 'Edit Profile', onTap: onEditProfile),
        btn(icon: Icons.workspace_premium, text: 'Premium', onTap: onPremium, gold: true),
        btn(icon: Icons.settings, text: 'Settings', onTap: onSettings),
        if (onAdminSeed != null) btn(icon: Icons.construction_rounded, text: 'Seed Demo', onTap: onAdminSeed!),
        btn(icon: Icons.logout, text: 'Log Out', onTap: onLogout, danger: true),
      ],
    );
  }
}
