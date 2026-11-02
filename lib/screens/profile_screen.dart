import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/notifications.dart';
import '../services/reminders.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<AppSettings> _settings = Db.settingsStream();
  late final Stream<List<Roadmap>> _roadmaps = Db.myRoadmaps();
  final _key = TextEditingController();
  final _model = TextEditingController();
  bool _loadedAi = false;
  bool _hideKey = true;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, dynamic> data, {bool resync = true}) async {
    await Db.saveSettings(data);
    if (resync) await Reminders.syncDaily();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<AppSettings>(
        stream: _settings,
        builder: (context, snap) {
          if (!snap.hasData) return const Loader();
          final s = snap.data!;
          if (!_loadedAi) {
            _key.text = s.geminiKey;
            _model.text = s.model;
            _loadedAi = true;
          }
          final reminder = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Avatar(Db.myName, size: 58),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(Db.myName, style: display(20)),
                      const SizedBox(height: 3),
                      Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted)),
                    ]),
                  ),
                ]),
              ),
              const SectionLabel('Daily routine'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  SwitchListTile(
                    value: s.reminderEnabled,
                    title: const Text('Daily "what to learn today" reminder'),
                    subtitle: const Text('Tells you your next topic every day',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    onChanged: (v) => _save({'reminderEnabled': v}),
                  ),
                  ListTile(
                    enabled: s.reminderEnabled,
                    leading: const Icon(Icons.schedule_rounded, color: AppColors.accent),
                    title: const Text('Reminder time'),
                    trailing: Text(reminder.format(context), style: display(16)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: reminder);
                      if (t != null) await _save({'reminderHour': t.hour, 'reminderMinute': t.minute});
                    },
                  ),
                  StreamBuilder<List<Roadmap>>(
                    stream: _roadmaps,
                    builder: (context, rs) {
                      final list = rs.data ?? const <Roadmap>[];
                      if (list.isEmpty) return const SizedBox.shrink();
                      final valid = list.any((r) => r.id == s.activeRoadmapId);
                      return ListTile(
                        leading: const Icon(Icons.route_rounded, color: AppColors.pink),
                        title: const Text('Daily focus'),
                        trailing: DropdownButton<String>(
                          value: valid ? s.activeRoadmapId : null,
                          hint: const Text('Auto'),
                          underline: const SizedBox.shrink(),
                          dropdownColor: AppColors.surface2,
                          items: [
                            for (final r in list)
                              DropdownMenuItem(
                                value: r.id,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(r.title, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                          ],
                          onChanged: (v) => _save({'activeRoadmapId': v}),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: AppColors.warning),
                    title: const Text('Send a test notification'),
                    onTap: () async {
                      await Notifs.requestPermissions();
                      await Notifs.showTest();
                    },
                  ),
                ]),
              ),
              const SectionLabel('AI tutor & exams'),
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text(
                    'StudyCircle uses Google Gemini. Get a free API key from Google AI Studio and paste it here. '
                    'It is stored privately in your account.',
                    style: TextStyle(color: AppColors.muted, height: 1.45, fontSize: 13),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse('https://aistudio.google.com/apikey'),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Get a free key'),
                    ),
                  ),
                  TextField(
                    controller: _key,
                    obscureText: _hideKey,
                    decoration: InputDecoration(
                      hintText: 'Gemini API key',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_hideKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hideKey = !_hideKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _model,
                    decoration: const InputDecoration(
                      hintText: 'Model (default gemini-2.5-flash)',
                      prefixIcon: Icon(Icons.memory_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GradientButton(
                    label: 'Save AI settings',
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      await _save({'geminiKey': _key.text.trim(), 'model': _model.text.trim()}, resync: false);
                      if (context.mounted) toast(context, 'AI settings saved.');
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                label: const Text('Sign out', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          );
        },
      ),
    );
  }
}
