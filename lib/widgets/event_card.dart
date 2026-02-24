import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/models/event.dart';
import 'package:panda_dating_app/services/event_service.dart';
import 'package:panda_dating_app/theme.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onOpen;
  const EventCard({super.key, required this.event, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d · h:mm a').format(event.startTime);
    final isFull = event.rsvpCount >= event.capacity;
    final rsvped = context.select<EventService, bool>((s) => s.rsvps.contains(event.id));

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: PandaColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
                gradient: PandaColors.gradientPrimary,
              ),
              child: Stack(
                children: [
                  Center(child: Text(event.bannerEmoji, style: const TextStyle(fontSize: 56))),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        event.type.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            event.format == 'online' ? Icons.videocam : Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(event.format.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(color: PandaColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.schedule, size: 14, color: PandaColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(date, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.place, size: 14, color: PandaColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(event.location, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 10),
                  Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: event.tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: PandaColors.bgInput,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(t, style: const TextStyle(color: PandaColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                      const Spacer(),
                      _RsvpButton(event: event, rsvped: rsvped, isFull: isFull),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final EventModel event;
  final bool rsvped;
  final bool isFull;
  const _RsvpButton({required this.event, required this.rsvped, required this.isFull});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isFull ? null : () => context.read<EventService>().toggleRsvp(event.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: rsvped ? null : PandaColors.gradientButton,
          color: rsvped ? PandaColors.bgInput : null,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.4)),
          boxShadow: rsvped ? null : [
            BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 12),
          ],
        ),
        child: Row(children: [
          Icon(isFull ? Icons.lock_clock : (rsvped ? Icons.check : Icons.confirmation_number), color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(isFull ? 'Full' : (rsvped ? 'RSVP’d' : 'RSVP Free'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }
}
