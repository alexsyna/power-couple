import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/backend.dart';
import '../domain/models.dart';
import '../state/app_controller.dart';
import 'common.dart';

/// Settings card for the signed-in user's name and picture.
class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showMessage(context, done, color: Vivid.grass);
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName(String current) async {
    final name = await showDialog<String>(context: context, builder: (_) => _NameDialog(initial: current));
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == current || !mounted) return;
    final app = AppScope.of(context);
    await _run(() => app.updateProfile(displayName: trimmed), done: 'Name updated');
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ChunkyButton(
              label: 'Choose from library',
              icon: const Icon(Icons.photo_library_rounded),
              color: Vivid.sky,
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            ChunkyButton(
              label: 'Take a photo',
              icon: const Icon(Icons.photo_camera_rounded),
              color: Vivid.sky,
              outlined: true,
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
          ]),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final XFile? file;
    try {
      // Small square-ish JPEG keeps uploads quick and storage tiny.
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );
    } catch (_) {
      if (mounted) {
        showMessage(context,
            source == ImageSource.camera ? 'Camera not available.' : 'Couldn\'t open your photos.',
            color: Vivid.berry);
      }
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final app = AppScope.of(context);
    await _run(() => app.uploadAvatarPhoto(bytes), done: 'Photo updated');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final me = app.memberById(app.me);
    final name = me?.displayName ?? '';
    final kind = me?.avatarKind ?? AvatarKind.initial;
    final color = personColor(app.household!.members, app.me);

    Widget option(AvatarKind k, String label, Widget preview, VoidCallback onTap) {
      final selected = kind == k;
      return Expanded(
        child: GestureDetector(
          onTap: _busy ? null : onTap,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Vivid.grape : Colors.transparent, width: 3),
              ),
              child: preview,
            ),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: selected ? Vivid.grape : Surface.of(context).muted,
                )),
          ]),
        ),
      );
    }

    return SectionCard(
      title: '😎 Your profile',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Stack(children: [
            PersonAvatar(userId: app.me, size: 72),
            if (_busy)
              const Positioned.fill(
                child: Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator())),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
              Text('This is how your partner sees you.', style: theme.textTheme.bodySmall),
            ]),
          ),
          IconButton(
            tooltip: 'Edit name',
            icon: const Icon(Icons.edit_rounded),
            onPressed: _busy ? null : () => _editName(name),
          ),
        ]),
        const SizedBox(height: 16),
        Text('PICTURE', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1, color: Surface.of(context).muted)),
        const SizedBox(height: 8),
        Row(children: [
          option(AvatarKind.initial, 'Initial', Avatar(name: name, color: color, size: 48),
              () => _run(() => app.updateProfile(avatarKind: AvatarKind.initial))),
          option(AvatarKind.boy, 'Boy', Avatar(name: name, color: color, size: 48, kind: AvatarKind.boy),
              () => _run(() => app.updateProfile(avatarKind: AvatarKind.boy))),
          option(AvatarKind.girl, 'Girl', Avatar(name: name, color: color, size: 48, kind: AvatarKind.girl),
              () => _run(() => app.updateProfile(avatarKind: AvatarKind.girl))),
          option(
            AvatarKind.photo,
            kind == AvatarKind.photo ? 'Change' : 'Photo',
            kind == AvatarKind.photo
                ? PersonAvatar(userId: app.me, size: 48)
                : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Vivid.sky.withValues(alpha: 0.15),
                      border: Border.all(color: Vivid.sky, width: 3),
                    ),
                    child: const Icon(Icons.add_a_photo_rounded, color: Vivid.sky, size: 22),
                  ),
            _choosePhoto,
          ),
        ]),
      ]),
    );
  }
}

/// Owns its text controller so it's disposed only after the dialog is gone.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'How your partner sees you'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ChunkyButton(label: 'Save', onPressed: () => Navigator.pop(context, _controller.text)),
            const SizedBox(height: 10),
            ChunkyButton(label: 'Cancel', outlined: true, color: Vivid.sky, onPressed: () => Navigator.pop(context)),
          ]),
        ],
      );
}
