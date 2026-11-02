import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TutorScreen extends StatefulWidget {
  final String? roadmapId;
  final String? initialPrompt;
  final bool standalone; // pushed as its own page (shows back button)
  const TutorScreen({super.key, this.roadmapId, this.initialPrompt, this.standalone = false});
  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatTurn> _turns = [];
  List<Roadmap> _roadmaps = [];
  Roadmap? _roadmap;
  Set<String> _done = {};
  bool _thinking = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final list = await Db.myRoadmapsOnce();
      final settings = await Db.settings();
      Roadmap? pick;
      for (final r in list) {
        if (r.id == (widget.roadmapId ?? settings.activeRoadmapId)) pick = r;
      }
      pick ??= list.isEmpty ? null : list.first;
      if (!mounted) return;
      setState(() {
        _roadmaps = list;
        _roadmap = pick;
      });
      await _loadProgress();
    } catch (_) {}
    if (widget.initialPrompt != null) _send(widget.initialPrompt!);
  }

  Future<void> _loadProgress() async {
    if (_roadmap == null) return;
    final d = await Db.progressOnce(_roadmap!.id);
    if (mounted) setState(() => _done = d);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _turns.add(ChatTurn(true, t));
      _thinking = true;
    });
    _toBottom();
    try {
      final reply = await AI.tutor(_turns, roadmap: _roadmap, done: _done);
      if (!mounted) return;
      setState(() => _turns.add(ChatTurn(false, reply)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _turns.add(ChatTurn(false, '⚠️ $e')));
    } finally {
      if (mounted) setState(() => _thinking = false);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lesson = _roadmap == null ? null : nextLesson(_roadmap!, _done);
    final suggestions = [
      if (lesson != null) 'Teach me "${lesson.topic.title}" step by step',
      if (lesson != null) 'Quiz me on ${lesson.section.title}',
      'Make a study plan for this week around my job',
      'What should I focus on next and why?',
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(gradient: AppColors.warmGradient, borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          SizedBox(width: 10),
          Text('AI Tutor'),
        ]),
        actions: [
          if (_turns.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              icon: Icon(Icons.refresh_rounded),
              onPressed: () => setState(_turns.clear),
            ),
        ],
      ),
      body: Column(children: [
        if (_roadmaps.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final r in _roadmaps)
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.title),
                      selected: _roadmap?.id == r.id,
                      onSelected: (_) {
                        setState(() => _roadmap = r);
                        _loadProgress();
                      },
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _turns.isEmpty
              ? ListView(padding: EdgeInsets.all(20), children: [
                  SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration:
                          BoxDecoration(gradient: AppColors.warmGradient, borderRadius: BorderRadius.circular(26)),
                      child: Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 42),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text('Your personal teacher', textAlign: TextAlign.center, style: display(22)),
                  SizedBox(height: 6),
                  Text(
                    _roadmap == null
                        ? 'Ask anything. Create a roadmap so I can teach around your syllabus.'
                        : 'I know your "${_roadmap!.title}" roadmap and what you have finished. '
                            'English, Urdu or Hinglish — all fine.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  SizedBox(height: 24),
                  for (final s in suggestions)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onTap: () => _send(s),
                        child: Row(children: [
                          Icon(Icons.bolt_rounded, color: AppColors.warning, size: 20),
                          SizedBox(width: 10),
                          Expanded(child: Text(s)),
                        ]),
                      ),
                    ),
                ])
              : ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                  itemCount: _turns.length + (_thinking ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _turns.length) return _Typing();
                    return _Bubble(turn: _turns[i]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, 8, 10, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: 'Ask about any topic…', isDense: true),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(_input.text),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.warmGradient),
                  child: Icon(Icons.arrow_upward_rounded, color: Colors.white),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatTurn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final me = turn.fromUser;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (me ? 0.8 : 0.9)),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: me ? AppColors.gradient : null,
          color: me ? null : AppColors.surface,
          border: me ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(turn.text,
            style: TextStyle(fontSize: 15, height: 1.5, color: me ? Colors.white : AppColors.text)),
      ),
    );
  }
}

class _Typing extends StatefulWidget {
  _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(
                      alpha: 0.3 + 0.7 * (((_c.value * 3 - i) % 3) < 1 ? 1 - ((_c.value * 3 - i) % 1) : 0)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
