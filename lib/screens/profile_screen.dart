import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../services/notifications.dart';
import '../services/reminders.dart';
import '../services/theme_controller.dart';
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
  bool _loadedAi = false;
  bool _hideKey = true;

  String _model = AI.fallbackModels.first;
  List<String> _models = AI.fallbackModels;
  bool _loadingModels = false;
  String? _keyStatus; // null = unknown, '' = ok, otherwise error text

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, dynamic> data, {bool resync = true}) async {
    await Db.saveSettings(data);
    if (resync) await Reminders.syncDaily();
  }

  /// Checks the key with Google and loads the models it can use.
  Future<void> _loadModels({bool showToast = false}) async {
    final key = _key.text.trim();
    if (key.isEmpty) return;
    setState(() => _loadingModels = true);
    try {
      final list = await AI.listModels(key);
      if (!mounted) return;
      setState(() {
        _models = list;
        if (!_models.contains(_model)) {
          _model = _models.contains('gemini-2.5-flash') ? 'gemini-2.5-flash' : _models.first;
        }
        _keyStatus = '';
      });
      if (showToast) toast(context, 'Key works ✓ — ${list.length} models available.');
    } catch (e) {
      if (mounted) setState(() => _keyStatus = e.toString());
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  String _hint(String m) {
    if (m.contains('flash-lite')) return 'fastest';
    if (m.contains('flash')) return 'fast';
    if (m.contains('pro')) return 'smartest';
    return '';
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
            _loadedAi = true;
            _key.text = s.geminiKey;
            _model = s.model;
            if (!_models.contains(_model)) _models = [..._models, _model];
            if (s.geminiKey.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadModels());
            }
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
                      Text(user?.email ?? '', style: TextStyle(color: AppColors.muted)),
                    ]),
                  ),
                ]),
              ),

              // ── Appearance ──
              const SectionLabel('Appearance'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, mode, _) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => ThemeController.set(v.first),
                  ),
                ),
              ),

              // ── Routine ──
              const SectionLabel('Daily routine'),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  SwitchListTile(
                    value: s.reminderEnabled,
                    title: const Text('Daily "what to learn today" reminder'),
                    subtitle: Text('Tells you your next topic every day',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    onChanged: (v) => _save({'reminderEnabled': v}),
                  ),
                  ListTile(
                    enabled: s.reminderEnabled,
                    leading: Icon(Icons.schedule_rounded, color: AppColors.accent),
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
                      final list = rs.data ?? <Roadmap>[];
                      if (list.isEmpty) return const SizedBox.shrink();
                      final valid = list.any((r) => r.id == s.activeRoadmapId);
                      return ListTile(
                        leading: Icon(Icons.route_rounded, color: AppColors.pink),
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
                    leading: Icon(Icons.notifications_active_outlined, color: AppColors.warning),
                    title: const Text('Send a test notification'),
                    onTap: () async {
                      await Notifs.requestPermissions();
                      await Notifs.showTest();
                    },
                  ),
                ]),
              ),

              // ── AI ──
              const SectionLabel('AI tutor & exams'),
              GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(
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
                    onSubmitted: (_) => _loadModels(showToast: true),
                    decoration: InputDecoration(
                      hintText: 'Gemini API key',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_hideKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hideKey = !_hideKey),
                      ),
                    ),
                  ),
                  if (_keyStatus != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(_keyStatus!.isEmpty ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          size: 16, color: _keyStatus!.isEmpty ? AppColors.success : AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_keyStatus!.isEmpty ? 'Key verified' : _keyStatus!,
                            style: TextStyle(
                                fontSize: 12,
                                color: _keyStatus!.isEmpty ? AppColors.success : AppColors.danger)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('$_model|${_models.length}'),
                        initialValue: _models.contains(_model) ? _model : null,
                        isExpanded: true,
                        dropdownColor: AppColors.surface2,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          prefixIcon: Icon(Icons.memory_rounded),
                        ),
                        items: [
                          for (final m in _models)
                            DropdownMenuItem(
                              value: m,
                              child: Row(children: [
                                Flexible(child: Text(m, overflow: TextOverflow.ellipsis)),
                                if (_hint(m).isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(_hint(m), style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ]),
                            ),
                        ],
                        onChanged: (v) => setState(() => _model = v ?? _model),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Check key & refresh models',
                      onPressed: _loadingModels ? null : () => _loadModels(showToast: true),
                      icon: _loadingModels
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Tap ↻ after pasting your key to load every model it can use.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  GradientButton(
                    label: 'Save AI settings',
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      await _save({'geminiKey': _key.text.trim(), 'model': _model}, resync: false);
                      if (context.mounted) toast(context, 'AI settings saved — using $_model.');
                      if (_keyStatus == null) _loadModels();
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              TextButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: Icon(Icons.logout_rounded, color: AppColors.danger),
                label: Text('Sign out', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          );
        },
      ),
    );
  }
}
