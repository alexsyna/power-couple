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
