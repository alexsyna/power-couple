import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/backend.dart';
import '../state/app_controller.dart';
import 'common.dart';
import 'logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startWithSignUp = false});

  final bool startWithSignUp;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  late bool _signUp = widget.startWithSignUp;
  bool _busy = false;
  bool _googleBusy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      if (_signUp) {
        final needsConfirm =
            await app.signUp(_email.text.trim(), _password.text, _name.text.trim());
        if (needsConfirm && mounted) {
          showMessage(context, 'Check your email to confirm, then sign in.');
          setState(() => _signUp = false);
        }
      } else {
        await app.signIn(_email.text.trim(), _password.text);
      }
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens Google's sign-in page; the app reacts when the session arrives.
  Future<void> _google() async {
    setState(() => _googleBusy = true);
    try {
      await AppScope.of(context).signInWithGoogle();
    } on BackendException catch (e) {
      if (mounted) showMessage(context, e.message, color: Vivid.berry);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final demo = AppScope.of(context).backend.isDemo;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: PowerCoupleLogo(size: 120)),
                    const SizedBox(height: 12),
                    const SizedBox(height: 8),
                    Text('Power Couple',
                        textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text('Beat the weekly boss together.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (demo) ...[
                      const SizedBox(height: 16),
                      const SectionCard(
                        child: Text('🧪 Demo mode: data stays on this device. Any email and password work.'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ChunkyButton(
                      label: 'Continue with Google',
                      outlined: true,
                      color: Surface.of(context).ink,
                      icon: const _GoogleMark(),
                      busy: _googleBusy,
                      onPressed: _busy ? null : _google,
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or with email', style: theme.textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 18),
                    if (_signUp) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Your name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'At least 8 characters' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    ChunkyButton(
                      label: _signUp ? 'Create account' : 'Sign in',
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                      child: Text(_signUp ? 'I already have an account' : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's four-colour "G", drawn so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 20, child: CustomPaint(painter: _GoogleMarkPainter()));
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.2;
    final rect = Rect.fromCircle(center: Offset(s / 2, s / 2), radius: (s - stroke) / 2);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = math.pi / 180;
    // Angles run clockwise from 3 o'clock; the opening sits between the red
    // (ending upper right) and the blue crossbar at 3 o'clock.
    canvas.drawArc(rect, 0, 45 * deg, false, arc(_blue));
    canvas.drawArc(rect, 45 * deg, 90 * deg, false, arc(_green));
    canvas.drawArc(rect, 135 * deg, 90 * deg, false, arc(_yellow));
    canvas.drawArc(rect, 225 * deg, 90 * deg, false, arc(_red));
    // The crossbar of the G.
    canvas.drawRect(Rect.fromLTRB(s / 2, s / 2 - stroke / 2, s, s / 2 + stroke / 2),
        Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter old) => false;
}
