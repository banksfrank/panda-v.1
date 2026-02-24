import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:panda_dating_app/openai/openai_config.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/services/discovery_service.dart';
import 'package:panda_dating_app/theme.dart';
import 'package:panda_dating_app/services/billing_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PandaSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const PandaSheetScaffold({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
              ...?actions,
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => const DiscoveryFilterSheet(),
    );
  }

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  late RangeValues _age;
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  final Set<String> _interests = {};

  final _interestOptions = const ['Hiking', 'Coffee', 'Cooking', 'Yoga', 'Travel', 'Photography', 'Reading', 'Music', 'Art', 'Gaming', 'Fitness', 'Tech', 'Pets', 'Outdoors', 'Foodie'];

  @override
  void initState() {
    super.initState();
    final current = context.read<DiscoveryService>().filters;
    _age = RangeValues(current.ageMin.toDouble(), current.ageMax.toDouble());
    _countryController.text = current.country ?? '';
    _cityController.text = current.city ?? '';
    _professionController.text = current.professionQuery ?? '';
    _interests.addAll(current.interests);
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PandaSheetScaffold(
      title: 'Discovery Filters',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Age range: ${_age.start.round()} – ${_age.end.round()}', style: const TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w700)),
            RangeSlider(
              values: _age,
              min: 18,
              max: 90,
              divisions: 72,
              activeColor: PandaColors.pink,
              inactiveColor: PandaColors.borderColor,
              onChanged: (v) => setState(() => _age = v),
            ),
            const SizedBox(height: 10),
            _Field(label: 'Country', controller: _countryController, hint: 'All countries'),
            const SizedBox(height: 10),
            _Field(label: 'City', controller: _cityController, hint: 'All cities'),
            const SizedBox(height: 10),
            _Field(label: 'Profession', controller: _professionController, hint: 'Any profession'),
            const SizedBox(height: 12),
            const Text('Interests', style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interestOptions
                  .map((i) => ChoiceChip(
                        label: Text(i, style: TextStyle(color: _interests.contains(i) ? Colors.white : PandaColors.textSecondary)),
                        selected: _interests.contains(i),
                        onSelected: (v) => setState(() => v ? _interests.add(i) : _interests.remove(i)),
                        backgroundColor: PandaColors.bgInput,
                        selectedColor: PandaColors.purple,
                        shape: StadiumBorder(side: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.6))),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<DiscoveryService>().resetFilters();
                      context.pop();
                    },
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final next = DiscoveryFilters(
                        ageMin: _age.start.round(),
                        ageMax: _age.end.round(),
                        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
                        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
                        professionQuery: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
                        interests: _interests,
                      );
                      context.read<DiscoveryService>().applyFilters(next);
                      context.pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    child: Ink(
                      decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ),
                    ),
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

class PremiumSheet extends StatelessWidget {
  const PremiumSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => const PremiumSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isPremium = auth.isPremium;

    Future<void> startPlan(BillingPlan plan) async {
      final billing = const BillingService();
      final url = await billing.createCheckoutSession(plan: plan);
      if (url == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start checkout. Please try again.')));
        }
        return;
      }

      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open checkout link.')));
      }
    }

    return PandaSheetScaffold(
      title: 'Panda Premium',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPremium ? 'You\'re Premium ✅' : 'Unlock the full dating experience',
            style: const TextStyle(color: PandaColors.textSecondary, height: 1.4, fontWeight: FontWeight.w800),
          ),
          if (auth.premiumUntil != null) ...[
            const SizedBox(height: 6),
            Text('Active until ${auth.premiumUntil!.toLocal().toString().split('.').first}', style: const TextStyle(color: PandaColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          const _BenefitRow(icon: Icons.all_inclusive, text: 'Unlimited swipes'),
          const _BenefitRow(icon: Icons.visibility, text: 'See who liked you'),
          const _BenefitRow(icon: Icons.bolt, text: 'Boost profile visibility'),
          const _BenefitRow(icon: Icons.calendar_month, text: 'Access premium events'),
          const _BenefitRow(icon: Icons.videocam, text: 'Host meetings & rooms'),
          const _BenefitRow(icon: Icons.tune, text: 'Advanced filters'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Choose a plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                _PlanButton(plan: BillingPlan.monthly, onTap: () => startPlan(BillingPlan.monthly)),
                const SizedBox(height: 10),
                _PlanButton(plan: BillingPlan.threeMonths, onTap: () => startPlan(BillingPlan.threeMonths), highlight: true),
                const SizedBox(height: 10),
                _PlanButton(plan: BillingPlan.sixMonths, onTap: () => startPlan(BillingPlan.sixMonths)),
                const SizedBox(height: 10),
                _PlanButton(plan: BillingPlan.year, onTap: () => startPlan(BillingPlan.year)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async => auth.refreshPremiumFromServer(),
                  child: const Text('Refresh status'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Local fallback toggle (useful while DB/webhook is not configured yet)
                    auth.setPremium(!isPremium);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                  child: Ink(
                    decoration: BoxDecoration(gradient: PandaColors.gradientGold, borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(child: Text('Continue (offline)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Payments are processed securely by Stripe. After checkout, return here and tap “Refresh status”.', style: TextStyle(color: PandaColors.textMuted, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}

class _PlanButton extends StatelessWidget {
  final BillingPlan plan;
  final VoidCallback onTap;
  final bool highlight;

  const _PlanButton({required this.plan, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final border = highlight ? PandaColors.gold.withValues(alpha: 0.75) : PandaColors.borderColor.withValues(alpha: 0.6);
    final bg = highlight ? PandaColors.purpleDeep.withValues(alpha: 0.35) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: PandaColors.purpleDeep.withValues(alpha: 0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: border)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('${plan.priceLabel} billed every ${plan == BillingPlan.year ? 'year' : (plan == BillingPlan.monthly ? 'month' : ' ${plan == BillingPlan.threeMonths ? 3 : 6} months')}', style: const TextStyle(color: PandaColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(gradient: highlight ? PandaColors.gradientGold : PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
              child: Text(highlight ? 'Best value' : 'Select', style: TextStyle(color: highlight ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = context.select<AuthService, List<String>>((s) => s.notifications);

    return PandaSheetScaffold(
      title: 'Notifications',
      actions: [
        if (items.isNotEmpty)
          TextButton(
            onPressed: () => context.read<AuthService>().clearNotifications(),
            child: const Text('Clear', style: TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w800)),
          ),
      ],
      child: items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('All caught up ✨', style: TextStyle(color: PandaColors.textMuted))),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, i) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notifications, color: PandaColors.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(items[i], style: const TextStyle(color: PandaColors.textSecondary, height: 1.4))),
                  ],
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: items.length,
            ),
    );
  }
}

class AiAssistantSheet extends StatefulWidget {
  const AiAssistantSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PandaColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => const AiAssistantSheet(),
    );
  }

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  final _input = TextEditingController();
  bool _loading = false;

  final List<_AiMsg> _messages = [
    const _AiMsg(
      isBot: true,
      text:
          'Hey! I\'m your Panda AI assistant. I can help with icebreakers, bio improvements, conversation tips, and safety reminders.\n\nWhat do you need?',
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    setState(() {
      _messages.add(_AiMsg(isBot: false, text: trimmed));
      _loading = true;
    });

    try {
      final openai = const OpenAiConfig();
      final reply = await openai.chat(
        model: 'gpt-4o-mini',
        messages: [
          {
            'role': 'system',
            'content':
                'You are Panda, a helpful dating assistant. Be concise, kind, practical, and safety-aware. Avoid explicit content. Give actionable suggestions.',
          },
          for (final m in _messages)
            {
              'role': m.isBot ? 'assistant' : 'user',
              'content': m.text,
            },
        ],
      );

      if (!mounted) return;
      setState(() => _messages.add(_AiMsg(isBot: true, text: reply)));
    } catch (e) {
      debugPrint('AI assistant failed: $e');
      if (!mounted) return;
      setState(() => _messages.add(const _AiMsg(isBot: true, text: 'Sorry — I had trouble reaching the AI service. Please try again.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PandaSheetScaffold(
      title: 'Panda AI Assistant',
      child: Column(
        children: [
          SizedBox(
            height: 340,
            child: ListView.separated(
              itemCount: _messages.length + (_loading ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (_loading && i == _messages.length) {
                  return const _AiBubble(isBot: true, text: 'Thinking…');
                }
                final m = _messages[i];
                return _AiBubble(isBot: m.isBot, text: m.text);
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Suggestion(text: 'Give me an icebreaker', onTap: () => _send('Give me 5 playful icebreakers for a dating chat.')),
              _Suggestion(text: 'Help with my bio', onTap: () => _send('Improve my dating bio: “${context.read<AuthService>().currentUser?.bio ?? 'New to Panda!'}”')),
              _Suggestion(text: 'Conversation tips', onTap: () => _send('Give me 5 conversation tips for a first chat.')),
              _Suggestion(text: 'Safety tips', onTap: () => _send('Share 6 safety tips for meeting someone from a dating app.')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: _send,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything…',
                    hintStyle: const TextStyle(color: PandaColors.textMuted),
                    filled: true,
                    fillColor: PandaColors.bgInput,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.5))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.5))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.full), borderSide: const BorderSide(color: PandaColors.pink)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  final t = _input.text;
                  _input.clear();
                  _send(t);
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full), boxShadow: [BoxShadow(color: PandaColors.pink.withValues(alpha: 0.25), blurRadius: 12)]),
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          const Text('If AI is unavailable, ensure your Dreamflow OpenAI proxy env vars are enabled for this project.', style: TextStyle(color: PandaColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Suggestion({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.5))),
        child: Text(text, style: const TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

class _AiMsg {
  final bool isBot;
  final String text;
  const _AiMsg({required this.isBot, required this.text});
}

class _AiBubble extends StatelessWidget {
  final bool isBot;
  final String text;

  const _AiBubble({required this.isBot, required this.text});

  @override
  Widget build(BuildContext context) {
    final bg = isBot ? PandaColors.bgInput : PandaColors.purpleDeep;
    final border = isBot ? PandaColors.borderColor.withValues(alpha: 0.5) : Colors.transparent;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: border)),
        child: Text(text, style: const TextStyle(color: Colors.white, height: 1.4)),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: PandaColors.textSecondary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _Field({required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
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
