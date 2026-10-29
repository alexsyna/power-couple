import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../domain/calendar.dart';
import '../domain/models.dart';
import '../state/app_controller.dart';

/// A partner's colour, by their position in the household.
Color personColor(List<Member> members, String? userId) {
  final i = members.indexWhere((m) => m.userId == userId);
  return i < 0
      ? const Color(0xFF8592A0)
      : Vivid.partnerColors[i % Vivid.partnerColors.length];
}

/// Vivid accent colours, the same in light and dark mode. Each has a darker
/// "shade" used for the raised bottom edge of chunky buttons and tiles.
class Vivid {
  static const grass = Color(0xFF46C21B);
  static const grassShade = Color(0xFF36961A);
  static const sky = Color(0xFF22A6EE);
  static const skyShade = Color(0xFF1782BF);
  static const sun = Color(0xFFFFC22E);
  static const sunShade = Color(0xFFDB9D00);
  static const flame = Color(0xFFFF8A1F);
  static const flameShade = Color(0xFFD86C08);
  static const berry = Color(0xFFFF4D5E);
  static const berryShade = Color(0xFFD13342);
  static const grape = Color(0xFF9B5CF6);
  static const grapeShade = Color(0xFF7840D4);

  static Color shadeOf(Color c) => switch (c) {
    grass => grassShade,
    sky => skyShade,
    sun => sunShade,
    flame => flameShade,
    berry => berryShade,
    grape => grapeShade,
    _ => Color.lerp(c, Colors.black, 0.22)!,
  };

  /// Stable colour per partner so names and avatars are recognisable.
  static const partnerColors = [sky, grape, flame, grass];
}

/// Neutral surface tokens, resolved per brightness.
class Surface extends ThemeExtension<Surface> {
  const Surface({
    required this.page,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
  });

  final Color page;
  final Color card;
  final Color line;
  final Color ink;
  final Color muted;

  static const light = Surface(
    page: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE3E7EB),
    ink: Color(0xFF2C3640),
    muted: Color(0xFF8592A0),
  );

  static const dark = Surface(
    page: Color(0xFF121D23),
    card: Color(0xFF1B2932),
    line: Color(0xFF33444F),
    ink: Color(0xFFF1F5F8),
    muted: Color(0xFF8FA0AD),
  );

  static Surface of(BuildContext context) =>
      Theme.of(context).extension<Surface>()!;

  @override
  Surface copyWith() => this;

  @override
  Surface lerp(Surface? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData buildTheme(Brightness brightness) {
  final s = brightness == Brightness.light ? Surface.light : Surface.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Vivid.grass,
    brightness: brightness,
    primary: Vivid.grass,
    onPrimary: Colors.white,
    secondary: Vivid.sky,
    error: Vivid.berry,
    surface: s.page,
    onSurface: s.ink,
  );
  final text = GoogleFonts.nunitoTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(bodyColor: s.ink, displayColor: s.ink);
  TextStyle? heavy(TextStyle? t) => t?.copyWith(fontWeight: FontWeight.w900);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: s.page,
    extensions: [s],
    textTheme: text.copyWith(
      displayLarge: heavy(text.displayLarge),
      displayMedium: heavy(text.displayMedium),
      displaySmall: heavy(text.displaySmall),
      headlineMedium: heavy(text.headlineMedium),
      headlineSmall: heavy(text.headlineSmall),
      titleLarge: heavy(text.titleLarge),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      bodyMedium: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: s.muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.page,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: s.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? const Color(0xFFF6F8FA)
          : s.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.line, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.line, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Vivid.sky, width: 2.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? Vivid.grass : s.line,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.page,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Vivid.sky.withValues(alpha: 0.16),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Vivid.sky, width: 2),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (st) => GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: st.contains(WidgetState.selected) ? Vivid.sky : s.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (st) => IconThemeData(
          color: st.contains(WidgetState.selected) ? Vivid.sky : s.muted,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: s.line, thickness: 2),
    popupMenuTheme: PopupMenuThemeData(
      color: s.card,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: s.line, width: 2),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: const Color(0xFF2C3640), borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      preferBelow: true,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.page,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.page,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

// ---------------------------------------------------------------- formatting

final _num = NumberFormat.decimalPattern();
String fmtInt(int n) => _num.format(n);

String weekLabel(DateTime weekStart) {
  final end = addDays(weekStart, 6);
  final sameMonth = weekStart.month == end.month;
  final start = DateFormat(sameMonth ? 'd' : 'd MMM').format(weekStart);
  return '$start – ${DateFormat('d MMM').format(end)}';
}

String dayLabel(DateTime date, DateTime today) {
  final diff = today.difference(date).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEEE d MMM').format(date);
}

String timeLabel(DateTime localTime) => DateFormat.Hm().format(localTime);

String medal(int rank) => switch (rank) {
  0 => '🥇',
  1 => '🥈',
  _ => '🏅',
};

// ---------------------------------------------------------------- components

/// The signature raised look: a face sitting on a darker edge.
class Raised extends StatelessWidget {
  const Raised({
    super.key,
    required this.face,
    required this.edge,
    required this.child,
    this.radius = 18,
    this.depth = 4,
    this.border,
    this.padding = EdgeInsets.zero,
  });

  final Color face;
  final Color edge;
  final Widget child;
  final double radius;
  final double depth;

  /// Optional outline (used by white cards so they read on white pages).
  final Color? border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(color: border ?? edge, borderRadius: r),
      padding: EdgeInsets.fromLTRB(
        border == null ? 0 : 2,
        border == null ? 0 : 2,
        border == null ? 0 : 2,
        depth,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(
            radius - (border == null ? 0 : 2),
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Big pressable button that sinks into its edge when tapped.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Vivid.grass,
    this.icon,
    this.outlined = false,
    this.busy = false,
    this.compact = false,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Widget? icon;

  /// White face with a coloured label, for secondary actions.
  final bool outlined;
  final bool busy;
  final bool compact;

  /// Overrides the label size, e.g. to fit two buttons side by side.
  final double? fontSize;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = Surface.of(context);
    final enabled = widget.onPressed != null && !widget.busy;
    final face = !enabled
        ? s.line
        : widget.outlined
        ? s.card
        : widget.color;
    final edge = !enabled
        ? s.line
        : widget.outlined
        ? s.line
        : Vivid.shadeOf(widget.color);
    final fg = !enabled
        ? s.muted
        : widget.outlined
        ? widget.color
        : Colors.white;
    const depth = 4.0;
    final pressed = _down && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 60),
          padding: EdgeInsets.only(top: pressed ? depth : 0),
          child: Raised(
            face: face,
            edge: edge,
            border: widget.outlined ? s.line : null,
            depth: pressed ? 0 : depth,
            radius: 16,
            child: SizedBox(
              height: widget.compact ? 40 : 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: widget.compact ? 8 : 16),
                  if (widget.busy)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fg,
                      ),
                    )
                  else if (widget.icon != null)
                    IconTheme(
                      data: IconThemeData(color: fg, size: 20),
                      child: widget.icon!,
                    ),
                  if (widget.busy || widget.icon != null)
                    const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label.toUpperCase(),
                        maxLines: 1,
                        style: GoogleFonts.nunito(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize:
                              widget.fontSize ?? (widget.compact ? 12 : 15),
                          letterSpacing: widget.compact ? 0.4 : 0.8,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: widget.compact ? 8 : 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White raised card with an optional title row.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.color,
    this.onTap,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;

  /// A vivid face colour instead of white; text should then be white.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Surface.of(context);
    final theme = Theme.of(context);
    final vivid = color != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: vivid ? Colors.white : null,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
        ],
        child,
      ],
    );
    final card = Raised(
      face: color ?? s.card,
      edge: vivid ? Vivid.shadeOf(color!) : s.line,
      border: vivid ? null : s.line,
      padding: const EdgeInsets.all(16),
      child: content,
    );
    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
  }
}

/// Thick rounded progress bar with a glossy highlight.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 16,
    this.track,
  });

  final double value;
  final Color? color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final s = Surface.of(context);
    final fill = color ?? Vivid.sun;
    final v = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: track ?? s.line,
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: Alignment.centerLeft,
      child: v == 0
          ? null
          : FractionallySizedBox(
              widthFactor: v < 0.04 ? 0.04 : v,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(height),
                ),
                padding: EdgeInsets.fromLTRB(
                  height / 2,
                  height * 0.22,
                  height / 2,
                  height * 0.5,
                ),
                child: height >= 12
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(height),
                        ),
                      )
                    : null,
              ),
            ),
    );
  }
}

/// Emoji on a tinted rounded square.
class EmojiBadge extends StatelessWidget {
  const EmojiBadge(
    this.emoji, {
    super.key,
    this.color = Vivid.sky,
    this.size = 44,
  });

  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(size * 0.32),
      border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
    ),
    child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
  );
}

/// Small rounded pill, e.g. "+40".
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color = Vivid.grass,
    this.filled = false,
  });

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: filled ? color : color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: GoogleFonts.nunito(
        color: filled ? Colors.white : Vivid.shadeOf(color),
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    ),
  );
}

/// Round avatar in the person's colour: their initial, a preset boy/girl
/// avatar, or their photo.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 40,
    this.kind = AvatarKind.initial,
    this.photoUrl,
  });

  final String name;
  final Color color;
  final double size;
  final AvatarKind kind;
  final String? photoUrl;

  static const presetEmoji = {AvatarKind.boy: '👦', AvatarKind.girl: '👧'};

  ImageProvider? get _photo {
    final url = photoUrl;
    if (kind != AvatarKind.photo || url == null) return null;
    if (url.startsWith('data:')) return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final emoji = presetEmoji[kind];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: emoji != null ? color.withValues(alpha: 0.2) : color,
        shape: BoxShape.circle,
        border: Border.all(color: Vivid.shadeOf(color), width: size < 30 ? 2 : 3),
        image: photo == null ? null : DecorationImage(image: photo, fit: BoxFit.cover),
      ),
      child: photo != null
          ? null
          : emoji != null
              ? Text(emoji, style: TextStyle(fontSize: size * 0.58, height: 1.1))
              : Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.42,
                  ),
                ),
    );
  }
}

/// A household member's avatar, using their chosen picture and colour.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.userId, this.size = 40});

  final String? userId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final m = app.memberById(userId);
    return Avatar(
      name: m?.displayName ?? '?',
      color: personColor(app.household?.members ?? const [], userId),
      size: size,
      kind: m?.avatarKind ?? AvatarKind.initial,
      photoUrl: m?.photoUrl,
    );
  }
}

/// Shared look for setting rows inside cards.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.trailing,
    this.color = Vivid.sky,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          EmojiBadge(emoji, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

void showMessage(
  BuildContext context,
  String text, {
  SnackBarAction? action,
  Color color = const Color(0xFF2C3640),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        action: action == null
            ? null
            : SnackBarAction(
                label: action.label.toUpperCase(),
                textColor: Colors.white,
                onPressed: action.onPressed,
              ),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // Undo stays available for a few seconds, then the message clears itself.
        persist: false,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
  String emoji = '🤔',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Text(emoji, style: const TextStyle(fontSize: 48)),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(body, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChunkyButton(
              label: action,
              color: destructive ? Vivid.berry : Vivid.grass,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            ChunkyButton(
              label: 'Cancel',
              outlined: true,
              color: Vivid.sky,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}
