import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/links.dart';

enum InviteKind {
  /// Join a Castle Climb.
  climb('c'),

  /// Join a partner's household.
  household('h');

  const InviteKind(this.path);
  final String path;
}

/// An invite from a link: https://powercouple.mindblo.app/c/CLIMB7.
@immutable
class Invite {
  const Invite(this.kind, this.code);

  final InviteKind kind;
  final String code;

  Uri get url => Uri.https(linkHost, '/${kind.path}/$code');

  /// Finds an invite in a link, a path, or a whole pasted message.
  static Invite? parse(String? text) {
    if (text == null) return null;
    final m = RegExp(r'(?:^|/)(c|h)/([A-Za-z0-9]{6,8})(?:[/?#\s]|$)').firstMatch(text);
    if (m == null) return null;
    // Only our own links (or the app's scheme), or a bare path (the web
    // app's own URL).
    final ours = text.contains(linkHost) || text.contains('localhost') || text.contains('${InviteLinks.appScheme}://invite');
    if (text.contains('://') && !ours) return null;
    final kind = m.group(1) == 'c' ? InviteKind.climb : InviteKind.household;
    return Invite(kind, m.group(2)!.toUpperCase());
  }

  static Invite? fromPrefs(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final kind = InviteKind.values.where((k) => k.name == parts[0]).firstOrNull;
    return kind == null ? null : Invite(kind, parts[1]);
  }

  String toPrefs() => '${kind.name}:$code';

  @override
  bool operator ==(Object other) => other is Invite && other.kind == kind && other.code == code;

  @override
  int get hashCode => Object.hash(kind, code);
}

/// Catches invites from every way they can arrive and keeps the latest one
/// until it's used, surviving sign-up and household setup (and restarts).
///
/// - Tapping a link with the app installed (iOS universal link).
/// - Opening the web app at /c/CODE.
/// - After installing from the landing page: the page copied the link, and
///   the first launch picks it up from the clipboard (iOS asks "Allow
///   Paste" once).
class InviteLinks extends ChangeNotifier {
  InviteLinks(this._prefs);

  final SharedPreferences? _prefs;
  StreamSubscription<Uri>? _sub;

  static const _key = 'pending_invite';
  static const _clipboardKey = 'invite_clipboard_checked';
  static const _channel = MethodChannel('powercouple/clipboard');

  /// Also accepted: org.powercouple.powercouple://invite/c/CODE.
  static const appScheme = 'org.powercouple.powercouple';

  /// Where the current invite came from: the web app's own address shows
  /// the landing page; the others go straight to joining.
  bool fromWebAddress = false;

  Invite? get pending => Invite.fromPrefs(_prefs?.getString(_key)) ?? _memory;
  Invite? _memory;

  void _set(Invite? i) {
    if (i == pending) return;
    _memory = i;
    if (i == null) {
      _prefs?.remove(_key);
    } else {
      _prefs?.setString(_key, i.toPrefs());
    }
    notifyListeners();
  }

  /// Leaves the web landing page for the web app, keeping the invite.
  void continueHere() {
    fromWebAddress = false;
    notifyListeners();
  }

  void clear() {
    fromWebAddress = false;
    _set(null);
  }

  /// Takes an invite from a link the app was opened with.
  void handle(Uri uri) {
    final i = Invite.parse(uri.toString());
    if (i != null) _set(i);
  }

  Future<void> start() async {
    if (kIsWeb) {
      final i = Invite.parse(Uri.base.path);
      if (i != null) {
        fromWebAddress = true;
        _set(i);
      }
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final links = AppLinks();
      _sub = links.uriLinkStream.listen(handle);
      final first = await links.getInitialLink();
      if (first != null) handle(first);
    } catch (e) {
      debugPrint('Invite links: $e');
    }
    await _checkClipboardOnce();
  }

  /// Right after installing from an invite page, the link waits on the
  /// clipboard. Only looked at on the very first launch, and only read
  /// when iOS says it probably holds a web link (checking doesn't prompt).
  Future<void> _checkClipboardOnce() async {
    final prefs = _prefs;
    if (prefs == null || (prefs.getBool(_clipboardKey) ?? false)) return;
    await prefs.setBool(_clipboardKey, true);
    if (pending != null) return;
    try {
      final hasLink = await _channel.invokeMethod<bool>('hasProbableWebURL') ?? false;
      if (!hasLink) return;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final i = Invite.parse(data?.text);
      if (i != null) _set(i);
    } catch (e) {
      debugPrint('Invite clipboard: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
