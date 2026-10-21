import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api.dart';
import '../../router/routes.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../home/home_data.dart';
import '../plus/states.dart';
import 'friends_repository.dart';

/// Picks a photo from the gallery; swapped out in tests.
final photoPickerProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => (await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      ))?.path,
);

const _languages = {
  'english': 'English',
  'pidgin': 'Pidgin',
  'yoruba': 'Yorùbá',
  'hausa': 'Hausa',
  'igbo': 'Igbo',
  'french': 'French',
  'arabic': 'Arabic',
};

/// 09 Profile & interests — design/screens/09-Profile.dc.html (FR-19).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _maxInterests = 5;
  static const _maxBio = 150;

  final _name = TextEditingController();
  final _city = TextEditingController();
  final _bio = TextEditingController();
  MyProfile? _profile;
  List<Interest> _catalogue = const [];
  List<String> _interests = [];
  List<String> _langs = [];

  /// FR-8 "nearby": a Nigerian state slug, or "".
  String _state = '';
  bool _saving = false;
  bool _uploading = false;

  FriendsRepository get _repo => ref.read(friendsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repo.profile(), _repo.interests()]);
      final profile = results[0] as MyProfile;
      setState(() {
        _apply(profile);
        _catalogue = results[1] as List<Interest>;
      });
    } on ApiFailure catch (e) {
      _toast(e.detail);
    }
  }

  void _apply(MyProfile p) {
    _profile = p;
    _name.text = p.firstName;
    _city.text = p.city;
    _state = p.state;
    _bio.text = p.bio;
    _interests = [for (final i in p.interests) i.slug];
    _langs = [...p.languages];
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _photoCall(Future<MyProfile> Function() call) async {
    setState(() => _uploading = true);
    try {
      final p = await call();
      setState(() => _profile = p);
      ref.invalidate(myProfileProvider);
    } on ApiFailure catch (e) {
      _toast(e.detail);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _addPhoto() async {
    final path = await ref.read(photoPickerProvider)();
    if (path != null) await _photoCall(() => _repo.addPhoto(path));
  }

  Future<void> _photoMenu(Photo photo, bool isMain) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMain)
              ListTile(
                title: const Text('Make main photo'),
                onTap: () => Navigator.pop(context, 'main'),
              ),
            ListTile(
              title: Text('Remove', style: KType.button.copyWith(color: KColors.danger)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == 'remove') await _photoCall(() => _repo.deletePhoto(photo.id));
    if (action == 'main') {
      final ids = [
        photo.id,
        for (final p in _profile!.photos)
          if (p.id != photo.id) p.id,
      ];
      await _photoCall(() => _repo.updateProfile(PatchedProfileUpdateRequest(photoOrder: ids)));
    }
  }

  Future<void> _pickState() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KColors.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            for (final MapEntry(key: slug, value: name) in nigerianStates.entries)
              ListTile(title: Text(name), onTap: () => Navigator.pop(context, slug)),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _state = picked);
  }

  Future<void> _addLanguage() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final MapEntry(key: code, value: label) in _languages.entries)
              if (!_langs.contains(code))
                ListTile(title: Text(label), onTap: () => Navigator.pop(context, code)),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _langs = [..._langs, picked]);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final p = await _repo.updateProfile(
        PatchedProfileUpdateRequest(
          firstName: _name.text.trim(),
          city: _city.text.trim(),
          state: _state,
          bio: _bio.text.trim(),
          interests: _interests,
          languages: _langs,
        ),
      );
      setState(() => _apply(p));
      ref.invalidate(myProfileProvider);
      if (mounted) context.canPop() ? context.pop() : context.go(Routes.home);
    } on ApiFailure catch (e) {
      _toast(e.detail);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewPaddingOf(context);
    final p = _profile;
    return Scaffold(
      body: p == null
          ? const Center(child: CircularProgressIndicator(color: KColors.coral))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(20, math.max(52, insets.top + 8), 20, 20),
                    children: [
                      Row(
                        children: [
                          KBackButton(
                            onPressed: () =>
                                context.canPop() ? context.pop() : context.go(Routes.home),
                          ),
                          Expanded(
                            child: Text(
                              'Edit profile',
                              textAlign: TextAlign.center,
                              style: KType.input.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Material(
                            color: KColors.surface,
                            borderRadius: BorderRadius.circular(KRadius.md),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(KRadius.md),
                              onTap: () => context.push(Routes.plus),
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 44),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                child: Text(
                                  'Lovelly Plus',
                                  style: KType.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: KColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _PhotoGrid(
                        photos: p.photos,
                        verified: p.isVerified,
                        busy: _uploading,
                        onAdd: _addPhoto,
                        onPhoto: _photoMenu,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(label: 'FIRST NAME', controller: _name),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(label: 'CITY', controller: _city),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Not in 09: used by the "Nearby" filter (M7 decision 1).
                      const FieldLabel('STATE'),
                      const SizedBox(height: 6),
                      Material(
                        color: KColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadius.md),
                          side: const BorderSide(color: KColors.line),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(KRadius.md),
                          onTap: _pickState,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              nigerianStates[_state] ?? 'Choose your state',
                              style: KType.button.copyWith(
                                color: _state.isEmpty ? KColors.muted : KColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        label: 'ABOUT ME',
                        controller: _bio,
                        maxLines: 3,
                        maxLength: _maxBio,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(child: FieldLabel('INTERESTS')),
                          Text(
                            '${_interests.length} of $_maxInterests picked',
                            style: KType.caption.copyWith(color: KColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final i in _catalogue)
                            _Pill(
                              label: i.label,
                              selected: _interests.contains(i.slug),
                              disabled:
                                  !_interests.contains(i.slug) &&
                                  _interests.length >= _maxInterests,
                              onTap: () => setState(() {
                                _interests.contains(i.slug)
                                    ? _interests.remove(i.slug)
                                    : _interests.add(i.slug);
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const FieldLabel('I SPEAK'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final code in _langs)
                            _Pill(
                              label: _languages[code] ?? code,
                              selected: false,
                              onTap: () => setState(() => _langs.remove(code)),
                              semantics: 'Remove ${_languages[code] ?? code}',
                            ),
                          if (_langs.length < _languages.length)
                            _Pill(
                              label: '+ Add',
                              selected: false,
                              dashed: true,
                              onTap: _addLanguage,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, math.max(30, insets.bottom + 12)),
                  decoration: const BoxDecoration(
                    color: KColors.navBar,
                    border: Border(top: BorderSide(color: KColors.surface2)),
                  ),
                  child: PrimaryButton(label: 'Save profile', busy: _saving, onPressed: _save),
                ),
              ],
            ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.verified,
    required this.busy,
    required this.onAdd,
    required this.onPhoto,
  });

  static const max = 6;

  final List<Photo> photos;
  final bool verified;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(Photo photo, bool isMain) onPhoto;

  /// Slot i: a photo, the add tile (first empty slot), or nothing.
  Widget _slot(int i, double height, double radius) {
    if (i < photos.length) {
      return _PhotoTile(
        photo: photos[i],
        height: height,
        radius: radius,
        main: i == 0,
        verified: verified,
        onTap: () => onPhoto(photos[i], i == 0),
      );
    }
    if (i == photos.length && photos.length < max) {
      return _AddTile(height: height, radius: radius, busy: busy, onTap: onAdd);
    }
    return SizedBox(height: height);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(flex: 2, child: _slot(0, 236, KRadius.field)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                _slot(1, 114, KRadius.lg),
                const SizedBox(height: 8),
                _slot(2, 114, KRadius.lg),
              ],
            ),
          ),
        ],
      ),
      if (photos.length >= 3) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            for (final i in [3, 4, 5]) ...[
              if (i > 3) const SizedBox(width: 8),
              Expanded(child: _slot(i, 114, KRadius.lg)),
            ],
          ],
        ),
      ],
    ],
  );
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.height,
    required this.radius,
    required this.main,
    required this.verified,
    required this.onTap,
  });

  final Photo photo;
  final double height;
  final double radius;
  final bool main;
  final bool verified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: main ? 'Main photo' : 'Photo',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KColors.avatarPlum,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(),
            ),
            if (main && verified)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: KColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KIconView(
                        KIcon.check,
                        size: 14,
                        color: KColors.background,
                        stroke: 2.6,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Selfie verified',
                        style: KType.small.copyWith(
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: KColors.background,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.height,
    required this.radius,
    required this.busy,
    required this.onTap,
  });

  final double height;
  final double radius;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add photo',
    excludeSemantics: true,
    child: InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _Dashed(radius),
        child: SizedBox(
          height: height,
          child: Center(
            child: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: KColors.muted),
                  )
                : const KIconView(KIcon.plus, size: 24, color: KColors.muted),
          ),
        ),
      ),
    ),
  );
}

class _Dashed extends CustomPainter {
  const _Dashed(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = KColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Dashed old) => old.radius != radius;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        onChanged: onChanged,
        style: KType.button.copyWith(height: 1.45),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(KRadius.md)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(KRadius.md),
            borderSide: const BorderSide(color: KColors.line),
          ),
          counterText: '', // 09 shows no counter; the 150 limit is still enforced
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.dashed = false,
    this.semantics,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final bool dashed;
  final VoidCallback onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? KColors.onCoral : (disabled || dashed ? KColors.muted : KColors.text);
    final bg = selected
        ? KColors.coral
        : (disabled || dashed ? KColors.transparent : KColors.surface);
    final border = selected ? KColors.coral : (disabled ? KColors.surface2 : KColors.line);
    final pill = Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: dashed ? null : Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: KType.body.copyWith(fontWeight: FontWeight.w500, color: fg),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: semantics ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: dashed ? CustomPaint(painter: _Dashed(KRadius.md), child: pill) : pill,
      ),
    );
  }
}
