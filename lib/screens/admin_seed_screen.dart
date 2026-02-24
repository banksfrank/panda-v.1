import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:panda_dating_app/supabase/supabase_bootstrap.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/widgets/panda_app_header.dart';
import 'package:panda_dating_app/widgets/panda_sheets.dart';
import 'package:panda_dating_app/utils/seeded_identity.dart';

class AdminSeedScreen extends StatefulWidget {
  const AdminSeedScreen({super.key});

  @override
  State<AdminSeedScreen> createState() => _AdminSeedScreenState();
}

class _AdminSeedScreenState extends State<AdminSeedScreen> {
  bool _loading = false;
  String? _status;

  int? _discoverableCount;
  int? _seededCount;
  int _countries = 0;

  int _perCity = 16;
  bool _dryRun = false;

  DateTime? _lastRunAt;
  Map<String, dynamic>? _lastRunResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshStats());
  }

  Future<void> _refreshStats() async {
    final supabase = SupabaseBootstrap.client;
    if (supabase == null || supabase.auth.currentUser == null) {
      setState(() {
        _status = 'Sign in to use admin tools.';
        _discoverableCount = null;
        _seededCount = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Loading stats…';
    });

    try {
      final res = await supabase.functions.invoke('seed_demo_profiles_v2', body: {'mode': 'stats', 'perCity': _perCity, 'seed': SeededIdentity.lockedBaseSeed});
      if (res.status != 200) {
        debugPrint('seed_demo_profiles stats failed: ${res.status} ${res.data}');
        if (mounted) setState(() => _status = 'Failed to load stats (${res.status}). See debug console.');
        return;
      }

      final data = _asJsonMap(res.data);
      setState(() {
        _discoverableCount = _asInt(data['discoverableProfiles']);
        _seededCount = _asInt(data['seededProfiles']);
        _countries = _asInt(data['countries']) ?? 0;
        _status = 'Stats updated.';
      });
    } catch (e) {
      debugPrint('Admin seed stats failed: $e');
      if (mounted) setState(() => _status = 'Failed to load stats. See debug console.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invoke(String mode) async {
    final supabase = SupabaseBootstrap.client;
    if (supabase == null || supabase.auth.currentUser == null) {
      setState(() => _status = 'Sign in to use admin tools.');
      return;
    }

    setState(() {
      _loading = true;
      _lastRunResult = null;
      _lastRunAt = null;
      _status = switch (mode) {
        'seed' => _dryRun ? 'Planning seed (dry run)…' : 'Seeding starter profiles…',
        'clear' => _dryRun ? 'Planning clear (dry run)…' : 'Clearing seeded profiles…',
        'seedAll' => _dryRun ? 'Planning clear + seed (dry run)…' : 'Clearing + seeding starter profiles…',
        _ => 'Running…',
      };
    });

    try {
      setState(() => _status = 'Contacting edge function…');

      final res = await supabase.functions.invoke(
        'seed_demo_profiles_v2',
        body: {
          'mode': mode,
          'perCity': _perCity,
          'dryRun': _dryRun,
          'seed': SeededIdentity.lockedBaseSeed,
        },
      );

      if (!mounted) return;

      if (res.status != 200) {
        debugPrint('seed_demo_profiles failed: ${res.status} ${res.data}');
        setState(() {
          _status = 'Request failed (${res.status}). See debug console.';
          _lastRunAt = DateTime.now();
          _lastRunResult = {
            'ok': false,
            'status': res.status,
            'data': res.data,
          };
        });
      } else {
        final result = _asJsonMap(res.data);
        setState(() {
          _status = 'Done.';
          _lastRunAt = DateTime.now();
          _lastRunResult = result;
        });
      }

      setState(() => _status = 'Refreshing stats…');
      await _refreshStats();

      if (mounted) setState(() => _status = 'Ready.');
    } catch (e) {
      debugPrint('Admin seed invoke failed: $e');
      if (mounted) {
        setState(() {
          _status = 'Failed. See debug console.';
          _lastRunAt = DateTime.now();
          _lastRunResult = {
            'ok': false,
            'error': e.toString(),
          };
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PandaColors.bgPrimary, PandaColors.bgSecondary])),
        child: SafeArea(
          child: Column(
            children: [
              PandaAppHeader(
                title: ShaderMask(
                  shaderCallback: (b) => PandaColors.gradientPrimary.createShader(b),
                  child: const Text('Admin Tools', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                onTapAi: () => AiAssistantSheet.show(context),
                onTapNotifications: () => NotificationsSheet.show(context),
                onTapPremium: () => PremiumSheet.show(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Demo profile seeding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 8),
                            const Text(
                              'This calls a Supabase Edge Function (service role) to seed starter profiles. It is idempotent: re-running only fills the missing rows for each country.',
                              style: TextStyle(color: PandaColors.textSecondary, height: 1.5),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                StatChip(label: 'Discoverable', value: _discoverableCount?.toString() ?? '—'),
                                StatChip(label: 'Seeded', value: _seededCount?.toString() ?? '—'),
                                StatChip(label: 'Countries', value: _countries.toString()),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Text('Per city', style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Slider(
                                    value: _perCity.toDouble(),
                                    min: 4,
                                    max: 30,
                                    divisions: 26,
                                    activeColor: PandaColors.pink,
                                    inactiveColor: PandaColors.borderColor,
                                    label: '$_perCity',
                                    onChanged: _loading ? null : (v) => setState(() => _perCity = v.round()),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SeedOptionRow(
                              title: 'Dry run',
                              subtitle: 'Returns a plan without inserting/deleting rows.',
                              value: _dryRun,
                              onChanged: _loading ? null : (v) => setState(() => _dryRun = v),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _loading ? null : _refreshStats,
                                    child: const Text('Refresh stats'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : () => _invoke('seed'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                                    child: Ink(
                                      decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 14),
                                        child: Center(child: Text('Seed profiles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : () => _invoke('seedAll'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                                child: Ink(
                                  decoration: BoxDecoration(gradient: PandaColors.gradientPrimary, borderRadius: BorderRadius.circular(AppRadius.full)),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Center(child: Text('Clear + Seed (seedAll)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _loading ? null : () => _invoke('clear'),
                                child: const Text('Clear seeded profiles', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: _loading
                                  ? const LinearProgressIndicator(key: ValueKey('loading'), color: PandaColors.pink, backgroundColor: PandaColors.bgInput)
                                  : const SizedBox(key: ValueKey('idle'), height: 4),
                            ),
                            if ((_status ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  _status!,
                                  key: ValueKey(_status),
                                  style: const TextStyle(color: PandaColors.textMuted, height: 1.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_lastRunResult != null)
                        AdminSeedResultCard(
                          runAt: _lastRunAt,
                          result: _lastRunResult!,
                          perCity: _perCity,
                          dryRun: _dryRun,
                        ),
                      const SizedBox(height: 14),
                      if (kDebugMode)
                        const Text(
                          'Debug note: Lock down this edge function in production (e.g., verify admin claims) before exposing it broadly.',
                          style: TextStyle(color: PandaColors.textMuted, fontSize: 12, height: 1.5),
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back, color: PandaColors.textSecondary),
                          label: const Text('Back'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

Map<String, dynamic> _asJsonMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{'raw': v};
}

class StatChip extends StatelessWidget {
  final String label;
  final String value;

  const StatChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
      child: Text('$label: $value', style: const TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class SeedOptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SeedOptionRow({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.45))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: PandaColors.textMuted, height: 1.35, fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: PandaColors.pink),
        ],
      ),
    );
  }
}

class AdminSeedResultCard extends StatelessWidget {
  final DateTime? runAt;
  final Map<String, dynamic> result;
  final int perCity;
  final bool dryRun;

  const AdminSeedResultCard({super.key, required this.runAt, required this.result, required this.perCity, required this.dryRun});

  @override
  Widget build(BuildContext context) {
    final ok = result['ok'] == true;
    final mode = '${result['mode'] ?? '—'}';
    final inserted = _asInt(result['inserted']);
    final deleted = _asInt(result['deleted']);
    final plannedInsert = _asInt(result['plannedInsert']);
    final plan = (result['plan'] is List) ? (result['plan'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Last run',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ok ? PandaColors.bgInput : PandaColors.bgInput,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: ok ? PandaColors.success.withValues(alpha: 0.55) : PandaColors.danger.withValues(alpha: 0.55)),
                ),
                child: Text(ok ? 'OK' : 'ERROR', style: TextStyle(color: ok ? PandaColors.success : PandaColors.danger, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatChip(label: 'Mode', value: mode),
              StatChip(label: 'Per city', value: '$perCity'),
              StatChip(label: 'Dry run', value: dryRun ? 'Yes' : 'No'),
              if (inserted != null) StatChip(label: 'Inserted', value: '$inserted'),
              if (deleted != null) StatChip(label: 'Deleted', value: '$deleted'),
              if (plannedInsert != null) StatChip(label: 'Planned', value: '$plannedInsert'),
            ],
          ),
          if (runAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Time: ${runAt!.toLocal()}'.split('.').first,
              style: const TextStyle(color: PandaColors.textMuted, height: 1.35, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          if (plan.isNotEmpty) ...[
            const Text('Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 10),
            AdminSeedPlanTable(plan: plan),
          ] else ...[
            const Text('Result', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 8),
            Text(_prettySummary(result), style: const TextStyle(color: PandaColors.textSecondary, height: 1.5)),
          ]
        ],
      ),
    );
  }

  String _prettySummary(Map<String, dynamic> result) {
    final err = result['error'];
    if (err != null) return 'Error: $err';

    final parts = <String>[];
    for (final key in ['inserted', 'deleted', 'plannedInsert', 'mode']) {
      if (result.containsKey(key)) parts.add('$key=${result[key]}');
    }
    if (parts.isEmpty) return result.toString();
    return parts.join(' • ');
  }
}

class AdminSeedPlanTable extends StatelessWidget {
  final List<Map<String, dynamic>> plan;
  const AdminSeedPlanTable({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
      child: Column(
        children: [
          const _PlanHeaderRow(),
          for (final row in plan) _PlanRow(row: row),
        ],
      ),
    );
  }
}

class _PlanHeaderRow extends StatelessWidget {
  const _PlanHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.45)))),
      child: const Row(
        children: [
          Expanded(flex: 6, child: Text('Country', style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
          Expanded(flex: 2, child: Text('Target', textAlign: TextAlign.right, style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
          Expanded(flex: 2, child: Text('Have', textAlign: TextAlign.right, style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
          Expanded(flex: 2, child: Text('Add', textAlign: TextAlign.right, style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12))),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _PlanRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final country = '${row['country'] ?? '—'}';
    final target = _asInt(row['target']) ?? 0;
    final existing = _asInt(row['existing']) ?? 0;
    final toInsert = _asInt(row['toInsert']) ?? 0;

    final highlight = toInsert > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.25)))),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Text(
              country,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Expanded(flex: 2, child: Text('$target', textAlign: TextAlign.right, style: const TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12))),
          Expanded(flex: 2, child: Text('$existing', textAlign: TextAlign.right, style: const TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12))),
          Expanded(
            flex: 2,
            child: Text(
              '$toInsert',
              textAlign: TextAlign.right,
              style: TextStyle(color: highlight ? PandaColors.pink : PandaColors.textSecondary, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
