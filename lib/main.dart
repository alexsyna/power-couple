import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/backend.dart';
import 'data/demo_backend.dart';
import 'data/supabase_backend.dart';
import 'domain/calendar.dart';
import 'state/app_controller.dart';
import 'ui/auth_screen.dart';
import 'ui/common.dart';
import 'ui/intro_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/shell.dart';

// Pass with --dart-define. Without them the app runs in on-device demo mode.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZones();
  final Backend backend;
  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    backend = DemoBackend();
  } else {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    backend = SupabaseBackend(Supabase.instance.client);
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(PowerCoupleApp(controller: AppController(backend), prefs: prefs));
}

const _introSeenKey = 'intro_seen';

class PowerCoupleApp extends StatelessWidget {
  const PowerCoupleApp({super.key, required this.controller, required this.prefs});

  final AppController controller;
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        child: MaterialApp(
          title: 'Power Couple',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: _Root(prefs: prefs),
          // On wide screens (web on a laptop) keep the phone layout, centred.
          builder: (context, child) => ColoredBox(
            color: Surface.of(context).line.withValues(alpha: 0.5),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          ),
        ),
      );
}

class _Root extends StatefulWidget {
  const _Root({required this.prefs});

  final SharedPreferences prefs;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  /// The walkthrough shows once, before the first sign-in.
  late bool _showIntro = !(widget.prefs.getBool(_introSeenKey) ?? false);
  bool _signUp = true;

  void _finishIntro(bool signUp) {
    widget.prefs.setBool(_introSeenKey, true);
    setState(() {
      _showIntro = false;
      _signUp = signUp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return switch (app.status) {
      AppStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AppStatus.signedOut when _showIntro => IntroScreen(onDone: _finishIntro),
      AppStatus.signedOut => AuthScreen(startWithSignUp: _signUp),
      AppStatus.needsHousehold => const OnboardingScreen(),
      AppStatus.ready => const Shell(),
    };
  }
}
