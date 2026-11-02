import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Stage { loading, error, quiz, result }

class ExamScreen extends StatefulWidget {
  final Roadmap roadmap;
  final Section section;
  const ExamScreen({super.key, required this.roadmap, required this.section});
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  _Stage _stage = _Stage.loading;
  String _error = '';
  List<ExamQuestion> _qs = [];
  List<int?> _answers = [];
  int _i = 0;
  final List<String> _seenHere = []; // questions from attempts in this visit

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _stage = _Stage.loading;
      _i = 0;
    });
    try {
      var past = <String>[];
      try {
        past = await Db.pastQuestions(widget.roadmap.id, widget.section.id);
      } catch (_) {}
      final qs = await AI.generateExam(widget.roadmap, widget.section,
          avoid: [..._seenHere.reversed, ...past.where((q) => !_seenHere.contains(q))]);
      if (!mounted) return;
      setState(() {
        _qs = qs;
        _answers = List<int?>.filled(qs.length, null);
        _stage = _Stage.quiz;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _stage = _Stage.error;
      });
    }
  }

  int get _score {
    var s = 0;
    for (var i = 0; i < _qs.length; i++) {
      if (_answers[i] == _qs[i].answer) s++;
    }
    return s;
  }

  Future<void> _finish() async {
    setState(() => _stage = _Stage.result);
    final questions = _qs.map((q) => q.question).toList();
    _seenHere.addAll(questions);
    try {
      await Db.saveExam(
          roadmap: widget.roadmap,
          section: widget.section,
          score: _score,
          total: _qs.length,
          questions: questions);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Section exam'),
          Text(widget.section.title,
              style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
        ]),
      ),
      body: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: switch (_stage) {
          _Stage.loading => _Preparing(key: ValueKey('loading')),
          _Stage.error => EmptyState(
              key: ValueKey('error'),
              icon: Icons.error_outline_rounded,
              title: 'Could not prepare the exam',
              subtitle: _error,
              action: GradientButton(label: 'Try again', icon: Icons.refresh, expand: false, onPressed: _generate),
            ),
          _Stage.quiz => _quiz(),
          _Stage.result => _result(),
        },
      ),
    );
  }

  Widget _quiz() {
    final q = _qs[_i];
    final last = _i == _qs.length - 1;
    return Column(
      key: ValueKey('q$_i'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
            Row(children: [
              Text('Question ${_i + 1} of ${_qs.length}',
                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
              Spacer(),
              Pill('Pass ≥ 60%', color: AppColors.warning),
            ]),
            SizedBox(height: 10),
            GradientBar(value: (_i + 1) / _qs.length, height: 6),
            SizedBox(height: 24),
            SelectableText(q.question, style: display(20, weight: FontWeight.w600).copyWith(height: 1.4)),
            SizedBox(height: 24),
            for (var o = 0; o < q.options.length; o++)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: _OptionTile(
                  letter: String.fromCharCode(65 + o),
                  text: q.options[o],
                  selected: _answers[_i] == o,
                  onTap: () => setState(() => _answers[_i] = o),
                ),
              ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              if (_i > 0) ...[
                GhostButton(label: 'Back', icon: Icons.arrow_back, onPressed: () => setState(() => _i--)),
                SizedBox(width: 10),
              ],
              Expanded(
                child: GradientButton(
                  label: last ? 'Submit exam' : 'Next',
                  icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  onPressed: _answers[_i] == null
                      ? null
                      : () {
                          if (last) {
                            _finish();
                          } else {
                            setState(() => _i++);
                          }
                        },
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _result() {
    final total = _qs.length;
    final pct = total == 0 ? 0.0 : _score / total;
    final passed = pct >= 0.6;
    return ListView(
      key: ValueKey('result'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        GlassCard(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            ProgressRing(
              value: pct,
              size: 150,
              stroke: 12,
              center: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(gradeFor(pct), style: display(44, color: passed ? AppColors.success : AppColors.danger)),
                Text('$_score / $total', style: TextStyle(color: AppColors.muted)),
              ]),
            ),
            SizedBox(height: 18),
            Text(passed ? 'Passed 🎓' : 'Not yet — keep going', style: display(22)),
            SizedBox(height: 6),
            Text(
              passed
                  ? 'Section "${widget.section.title}" is officially cleared.'
                  : 'Review the explanations below, revisit your notes, then retake with fresh questions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            SizedBox(height: 18),
            Row(children: [
              Expanded(child: GhostButton(label: 'Retake', icon: Icons.refresh_rounded, onPressed: _generate)),
              SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                    label: 'Done', icon: Icons.check_rounded, onPressed: () => Navigator.pop(context)),
              ),
            ]),
          ]),
        ),
        SectionLabel('Review'),
        for (var i = 0; i < _qs.length; i++) _review(i),
      ],
    );
  }

  Widget _review(int i) {
    final q = _qs[i];
    final mine = _answers[i];
    final right = mine == q.answer;
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: right ? AppColors.success : AppColors.danger, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('${i + 1}. ${q.question}', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
          SizedBox(height: 10),
          if (!right && mine != null)
            Text('Your answer: ${q.options[mine]}', style: TextStyle(color: AppColors.danger, fontSize: 13)),
          Text('Correct: ${q.options[q.answer]}', style: TextStyle(color: AppColors.success, fontSize: 13)),
          if (q.explanation.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(q.explanation, style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _OptionTile({required this.letter, required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppColors.gradient : null,
                color: selected ? null : AppColors.surface2,
              ),
              child: Text(letter, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.text)),
            ),
            SizedBox(width: 14),
            Expanded(child: Text(text, style: TextStyle(fontSize: 15, height: 1.35))),
          ]),
        ),
      ),
    );
  }
}

class _Preparing extends StatelessWidget {
  const _Preparing({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(strokeWidth: 5, color: AppColors.primary),
        ),
        SizedBox(height: 24),
        Text('Your examiner is writing questions…', style: display(18)),
        SizedBox(height: 6),
        Text('Fresh questions every attempt.', style: TextStyle(color: AppColors.muted)),
      ]),
    );
  }
}
