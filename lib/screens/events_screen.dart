import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/models/event.dart';
import 'package:panda_dating_app/services/event_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/widgets/event_card.dart';
import 'package:panda_dating_app/widgets/panda_app_header.dart';
import 'package:panda_dating_app/widgets/panda_sheets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    const filters = <String, String>{
      'all': 'All',
      'speed_dating': 'Speed Dating',
      'cultural': 'Cultural',
      'professional': 'Professional',
      'online': 'Online',
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PandaColors.bgPrimary, PandaColors.bgSecondary]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              PandaAppHeader(
                title: Row(
                  children: [
                    ShaderMask(shaderCallback: (b) => PandaColors.gradientPrimary.createShader(b), child: const Text('Events', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openCreateEvent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.22), blurRadius: 12)]),
                        child: Row(children: const [Icon(Icons.add, color: Colors.white, size: 18), SizedBox(width: 6), Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))]),
                      ),
                    ),
                  ],
                ),
                onTapAi: () => AiAssistantSheet.show(context),
                onTapNotifications: () => NotificationsSheet.show(context),
                onTapPremium: () => PremiumSheet.show(context),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final key = filters.keys.elementAt(i);
                    final label = filters[key]!;
                    final active = _activeFilter == key;
                    return GestureDetector(
                      onTap: () => setState(() => _activeFilter = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: active ? PandaColors.gradientButton : null,
                          color: active ? null : PandaColors.bgCard,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(label, style: TextStyle(color: active ? Colors.white : PandaColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: filters.length,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Consumer<EventService>(
                  builder: (context, service, _) {
                    if (service.isLoading) return const Center(child: CircularProgressIndicator(color: PandaColors.pink));
                    final list = service.events.where((e) => _matchesFilter(e)).toList();
                    if (list.isEmpty) return const Center(child: Text('No events match your filter', style: TextStyle(color: PandaColors.textMuted)));

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (_, i) => EventCard(event: list[i], onOpen: () => _openEventDetail(list[i])),
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemCount: list.length,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(EventModel e) {
    switch (_activeFilter) {
      case 'speed_dating':
        return e.type == 'speed_dating';
      case 'online':
        return e.format == 'online';
      case 'cultural':
        return e.tags.any((t) => t.toLowerCase().contains('culture'));
      case 'professional':
        return e.tags.any((t) => t.toLowerCase().contains('network')) || e.title.toLowerCase().contains('network');
      default:
        return true;
    }
  }

  void _openEventDetail(EventModel event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => _EventDetailSheet(event: event),
    );
  }

  Future<void> _openCreateEvent() async {
    final title = TextEditingController();
    final location = TextEditingController();
    final desc = TextEditingController();
    final capacity = TextEditingController(text: '50');
    String type = 'speed_dating';
    String format = 'online';
    DateTime start = DateTime.now().add(const Duration(days: 1, hours: 19));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Create Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
                IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 10),
            _Field(label: 'Event Name', controller: title, hint: 'Speed Dating Night'),
            const SizedBox(height: 10),
            _DropdownRow(
              label: 'Type',
              value: type,
              items: const {'speed_dating': 'Speed Dating', 'cultural': 'Cultural Event', 'professional': 'Professional Networking', 'online': 'Online Mixer'},
              onChanged: (v) => setState(() => type = v),
            ),
            const SizedBox(height: 10),
            _DropdownRow(
              label: 'Format',
              value: format,
              items: const {'online': 'Online', 'in_person': 'Physical', 'hybrid': 'Hybrid'},
              onChanged: (v) => setState(() => format = v),
            ),
            const SizedBox(height: 10),
            const Text('Date & Time', style: TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: start, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked == null) return;
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
                if (t == null) return;
                start = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
                if (context.mounted) (context as Element).markNeedsBuild();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
                child: Row(children: [
                  const Icon(Icons.schedule, color: PandaColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text(DateFormat.yMMMEd().add_jm().format(start), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            _Field(label: 'Location / Link', controller: location, hint: 'Venue or meeting link'),
            const SizedBox(height: 10),
            _Field(label: 'Max Attendees', controller: capacity, hint: '50', keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _Field(label: 'Description', controller: desc, hint: 'Tell people what to expect', maxLines: 3),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                child: Ink(
                  decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await context.read<EventService>().createEvent(
            title: title.text,
            description: desc.text,
            startTime: start,
            endTime: start.add(const Duration(hours: 2)),
            location: location.text,
            type: type,
            format: format,
            capacity: int.tryParse(capacity.text) ?? 50,
            tags: type == 'cultural'
                ? const ['Culture']
                : type == 'professional'
                    ? const ['Networking']
                    : const [],
            bannerEmoji: type == 'speed_dating'
                ? '💘'
                : type == 'professional'
                    ? '💼'
                    : type == 'cultural'
                        ? '🌍'
                        : '🎉',
          );
    } catch (e) {
      debugPrint('Create event failed: $e');
    }
  }
}

class _EventDetailSheet extends StatelessWidget {
  final EventModel event;
  const _EventDetailSheet({required this.event});

  @override
  Widget build(BuildContext context) {
    final rsvped = context.select<EventService, bool>((s) => s.rsvps.contains(event.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(event.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(event.format == 'online' ? Icons.videocam : Icons.place, color: PandaColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(event.location, style: const TextStyle(color: PandaColors.textSecondary))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule, color: PandaColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Text('${DateFormat.yMMMEd().format(event.startTime)} · ${DateFormat.jm().format(event.startTime)}', style: const TextStyle(color: PandaColors.textSecondary)),
          ]),
          const SizedBox(height: 12),
          Text(event.description, style: const TextStyle(color: PandaColors.textSecondary, height: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.read<EventService>().toggleRsvp(event.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: rsvped ? null : PandaColors.gradientButton,
                      color: rsvped ? PandaColors.bgInput : null,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: rsvped ? null : [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 14)],
                    ),
                    alignment: Alignment.center,
                    child: Text(rsvped ? 'Cancel RSVP' : 'RSVP Free', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.4))),
                child: const Icon(Icons.share, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({required this.label, required this.controller, required this.hint, this.maxLines = 1, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: PandaColors.textMuted),
            filled: true,
            fillColor: PandaColors.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: PandaColors.pink)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropdownRow({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: PandaColors.bgCard,
              isExpanded: true,
              iconEnabledColor: PandaColors.textSecondary,
              items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
