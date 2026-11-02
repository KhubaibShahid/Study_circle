import 'package:flutter/material.dart';

import '../services/db.dart';
import '../services/notifications.dart';
import '../services/reminders.dart';
import 'circles_screen.dart';
import 'profile_screen.dart';
import 'roadmaps_screen.dart';
import 'today_screen.dart';
import 'tutor_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  // Survives the full rebuild that happens when the theme changes.
  static int _savedIndex = 0;
  static String? _bootUid;

  int _index = _savedIndex;
  final _todayKey = GlobalKey<TodayScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_bootUid != Db.uid) {
      _bootUid = Db.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await Db.ensureProfile();
        } catch (_) {}
        await Notifs.requestPermissions();
        await Reminders.syncAll();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Every time the app comes back to the foreground, pick up new/changed classes
  // and refresh the text of the daily reminder.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Reminders.syncAll();
      _todayKey.currentState?.refresh();
    }
  }

  void _go(int i) {
    setState(() => _index = _savedIndex = i);
    if (i == 0) _todayKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        TodayScreen(key: _todayKey, onOpenTab: _go),
        const RoadmapsScreen(),
        const CirclesScreen(),
        const TutorScreen(),
        const ProfileScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny_rounded), label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: 'Roadmaps'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Circles'),
          NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Tutor'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
