import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/notifications.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
  ));
  // On Android, Firebase reads its config from android/app/google-services.json.
  await Firebase.initializeApp();
  await Notifs.init();
  runApp(const StudyCircleApp());
}

class StudyCircleApp extends StatelessWidget {
  const StudyCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyCircle',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Loader());
          }
          return snap.data == null ? const AuthScreen() : const HomeShell();
        },
      ),
    );
  }
}
