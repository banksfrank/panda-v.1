import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panda_dating_app/models/user.dart';
import 'package:panda_dating_app/services/auth_service.dart';
import 'package:panda_dating_app/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 5;

  final PageController _pageController = PageController();
  int _step = 0;

  DateTime? _dob;
  String _gender = '';
  String _preference = '';

  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  final _professionController = TextEditingController();
  final _tribeController = TextEditingController();
  final _bioController = TextEditingController();

  final Set<String> _interests = {};
  final List<String> _photos = List.filled(5, '');

  final _interestOptions = const [
    'Hiking',
    'Coffee',
    'Cooking',
    'Yoga',
    'Travel',
    'Photography',
    'Reading',
    'Music',
    'Art',
    'Gaming',
    'Fitness',
    'Tech',
    'Pets',
    'Outdoors',
    'Foodie',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _dob = user.dateOfBirth;
      _gender = user.gender == 'Not specified' ? '' : user.gender;
      _preference = user.lookingFor == 'Not specified' ? '' : user.lookingFor;
      _countryController.text = user.country ?? '';
      _cityController.text = user.city ?? '';
      _professionController.text = user.profession ?? '';
      _tribeController.text = user.tribe ?? '';
      _bioController.text = user.bio;
      _interests.addAll(user.interests);
      for (int i = 0; i < _photos.length && i < user.photos.length; i++) {
        _photos[i] = user.photos[i];
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    _tribeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  double get _progress => (_step + 1) / _steps;

  void _next() {
    if (_step < _steps - 1) {
      setState(() => _step += 1);
      _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
      return;
    }
    _finish();
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _pageController.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _finish() async {
    final auth = context.read<AuthService>();
    final existing = auth.currentUser;
    final now = DateTime.now();

    final photos = _photos.where((p) => p.trim().isNotEmpty).toList();
    final city = _cityController.text.trim().isEmpty ? null : _cityController.text.trim();
    final country = _countryController.text.trim().isEmpty ? null : _countryController.text.trim();
    final location = [city, country].whereType<String>().where((e) => e.isNotEmpty).join(', ');

    final base = existing;
    if (base == null) {
      debugPrint('Onboarding finish called without an authenticated user; redirecting to /auth');
      if (mounted) context.go('/auth');
      return;
    }

    final next = base.copyWith(
      bio: _bioController.text.trim(),
      gender: _gender.trim().isEmpty ? 'Not specified' : _gender.trim(),
      lookingFor: _preference.trim().isEmpty ? 'Not specified' : _preference.trim(),
      dateOfBirth: _dob,
      city: city,
      country: country,
      profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
      tribe: _tribeController.text.trim().isEmpty ? null : _tribeController.text.trim(),
      location: location.isEmpty ? (base.location) : location,
      interests: _interests.toList(),
      photos: photos,
      updatedAt: now,
    );

    await auth.updateProfile(next);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
    } catch (e) {
      debugPrint('Failed to persist onboarding_complete: $e');
    }

    if (mounted) context.go('/home');
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100, 1, 1),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: PandaColors.pink)), child: child!),
    );

    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _editPhotoUrl(int index) async {
    final controller = TextEditingController(text: _photos[index]);
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PandaColors.bgCard,
        title: const Text('Photo URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'https://…', hintStyle: TextStyle(color: PandaColors.textMuted)),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => context.pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (url == null) return;
    setState(() => _photos[index] = url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [PandaColors.bgPrimary, PandaColors.bgSecondary]),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    _Header(step: _step, steps: _steps, onBack: _back, onSkip: _finish),
                    const SizedBox(height: 8),
                    _ProgressBar(progress: _progress),
                    const SizedBox(height: 10),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _Step1About(dob: _dob, gender: _gender, preference: _preference, onPickDob: _pickDob, onGender: (v) => setState(() => _gender = v), onPreference: (v) => setState(() => _preference = v)),
                          _Step2Location(country: _countryController, city: _cityController),
                          _Step3Details(profession: _professionController, tribe: _tribeController, bio: _bioController),
                          _Step4Interests(options: _interestOptions, selected: _interests, onToggle: (i, v) => setState(() => v ? _interests.add(i) : _interests.remove(i))),
                          _Step5Photos(photos: _photos, onTapSlot: _editPhotoUrl),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _Footer(step: _step, steps: _steps, canContinue: _canContinue(), onNext: _next),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _canContinue() {
    if (_step == 0) return _dob != null && _gender.trim().isNotEmpty && _preference.trim().isNotEmpty;
    if (_step == 1) return _countryController.text.trim().isNotEmpty && _cityController.text.trim().isNotEmpty;
    if (_step == 2) return _professionController.text.trim().isNotEmpty && _bioController.text.trim().isNotEmpty;
    if (_step == 3) return _interests.length >= 3;
    if (_step == 4) return _photos.where((p) => p.trim().isNotEmpty).length >= 3;
    return true;
  }
}

class _Header extends StatelessWidget {
  final int step;
  final int steps;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _Header({required this.step, required this.steps, required this.onBack, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: step == 0 ? null : onBack,
          style: IconButton.styleFrom(backgroundColor: PandaColors.bgCard, disabledBackgroundColor: PandaColors.bgCard, shape: const CircleBorder()),
          icon: Icon(Icons.arrow_back, color: step == 0 ? PandaColors.textMuted : PandaColors.textSecondary, size: 18),
        ),
        Text('Step ${step + 1} of $steps', style: const TextStyle(color: PandaColors.textMuted, fontSize: 13, fontWeight: FontWeight.w700)),
        TextButton(onPressed: onSkip, child: const Text('Skip', style: TextStyle(color: PandaColors.textMuted, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(4)),
      child: LayoutBuilder(
        builder: (context, c) => Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            width: c.maxWidth * progress,
            decoration: BoxDecoration(gradient: PandaColors.gradientPrimary, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final int step;
  final int steps;
  final bool canContinue;
  final VoidCallback onNext;

  const _Footer({required this.step, required this.steps, required this.canContinue, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canContinue ? onNext : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
        child: Ink(
          decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(step == steps - 1 ? 'Finish' : 'Continue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step1About extends StatelessWidget {
  final DateTime? dob;
  final String gender;
  final String preference;
  final VoidCallback onPickDob;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onPreference;

  const _Step1About({required this.dob, required this.gender, required this.preference, required this.onPickDob, required this.onGender, required this.onPreference});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('About You'),
          const _Desc('Let\'s set up your profile basics'),
          const SizedBox(height: 16),
          const _Label('Date of Birth'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.6))),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: PandaColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text(dob == null ? 'Select date' : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Dropdown(label: 'Gender', value: gender, items: const ['Male', 'Female', 'Non-binary', 'Other'], onChanged: onGender),
          const SizedBox(height: 14),
          _Dropdown(label: 'I\'m interested in', value: preference, items: const ['Women', 'Men', 'Everyone'], onChanged: onPreference),
        ],
      ),
    );
  }
}

class _Step2Location extends StatelessWidget {
  final TextEditingController country;
  final TextEditingController city;

  const _Step2Location({required this.country, required this.city});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Where are you?'),
          const _Desc('Help us find people near you'),
          const SizedBox(height: 16),
          _TextField(label: 'Country', controller: country, hint: 'e.g. United States'),
          const SizedBox(height: 14),
          _TextField(label: 'City', controller: city, hint: 'e.g. San Francisco'),
        ],
      ),
    );
  }
}

class _Step3Details extends StatelessWidget {
  final TextEditingController profession;
  final TextEditingController tribe;
  final TextEditingController bio;

  const _Step3Details({required this.profession, required this.tribe, required this.bio});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('More about you'),
          const _Desc('Help others know who you are'),
          const SizedBox(height: 16),
          _TextField(label: 'Profession', controller: profession, hint: 'e.g. Software Engineer'),
          const SizedBox(height: 14),
          _TextField(label: 'Culture / Tribe (optional)', controller: tribe, hint: 'e.g. Yoruba, Sami, Mestizo'),
          const SizedBox(height: 14),
          _TextField(label: 'Bio', controller: bio, hint: 'Tell people about yourself…', maxLines: 4),
        ],
      ),
    );
  }
}

class _Step4Interests extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String, bool) onToggle;

  const _Step4Interests({required this.options, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Your Interests'),
          const _Desc('Select at least 3 interests'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (i) => ChoiceChip(
                    label: Text(i, style: TextStyle(color: selected.contains(i) ? Colors.white : PandaColors.textSecondary, fontWeight: FontWeight.w700)),
                    selected: selected.contains(i),
                    onSelected: (v) => onToggle(i, v),
                    backgroundColor: PandaColors.bgInput,
                    selectedColor: PandaColors.purple,
                    shape: StadiumBorder(side: BorderSide(color: PandaColors.borderColor.withValues(alpha: 0.6))),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Step5Photos extends StatelessWidget {
  final List<String> photos;
  final Future<void> Function(int) onTapSlot;

  const _Step5Photos({required this.photos, required this.onTapSlot});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Add Photos'),
          const _Desc('Add 3–5 photos of yourself (URLs for now)'),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 3 / 4),
            itemBuilder: (context, i) {
              final url = photos[i];
              final filled = url.trim().isNotEmpty;
              return GestureDetector(
                onTap: () => onTapSlot(i),
                child: Container(
                  decoration: BoxDecoration(color: PandaColors.bgCard, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: filled ? PandaColors.pink : PandaColors.borderColor.withValues(alpha: 0.7), width: 1.5)),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: filled
                              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _empty(i))
                              : _empty(i),
                        ),
                      ),
                      if (filled)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      if (i == 0)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(gradient: PandaColors.gradientButton, borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: const Text('Main', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _empty(int i) {
    return Container(
      color: PandaColors.bgCard,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: PandaColors.textMuted),
            const SizedBox(height: 4),
            Text(i == 0 ? 'Main photo' : 'Photo ${i + 1}', style: const TextStyle(color: PandaColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => PandaColors.gradientPrimary.createShader(r),
      child: Text(text, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }
}

class _Desc extends StatelessWidget {
  final String text;
  const _Desc(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: const TextStyle(color: PandaColors.textSecondary, height: 1.4)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: const TextStyle(color: PandaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8));
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _TextField({required this.label, required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
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

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _Dropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: PandaColors.bgInput, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: PandaColors.borderColor.withValues(alpha: 0.6))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.trim().isEmpty ? null : value,
              isExpanded: true,
              dropdownColor: PandaColors.bgCard,
              iconEnabledColor: PandaColors.textSecondary,
              hint: const Text('Select', style: TextStyle(color: PandaColors.textMuted)),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))).toList(),
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
