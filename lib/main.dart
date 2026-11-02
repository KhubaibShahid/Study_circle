import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/notifications.dart';
import 'services/theme_controller.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On Android, Firebase reads its config from android/app/google-services.json.
  await Firebase.initializeApp();
  await Notifs.init();
  await ThemeController.load();
  runApp(const StudyCircleApp());
}

class StudyCircleApp extends StatefulWidget {
  const StudyCircleApp({super.key});
  @override
  State<StudyCircleApp> createState() => _StudyCircleAppState();
}

class _StudyCircleAppState extends State<StudyCircleApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeController.mode.addListener(_rebuild);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ThemeController.mode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  void didChangePlatformBrightness() {
    if (ThemeController.mode.value == ThemeMode.system) setState(() {});
  }

  bool get _isDark {
    switch (ThemeController.mode.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark;
    final theme = buildTheme(dark); // also switches AppColors
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    ));
    // The key rebuilds every screen with the new palette.
    return MaterialApp(
      key: ValueKey(dark),
      title: 'StudyCircle',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Loader());
          }
          return snap.data == null ? const AuthScreen() : const HomeShell();
        },
      ),
    );
  }
}
