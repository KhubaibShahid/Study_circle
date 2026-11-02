import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? gradient;
  final Color? color;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.gradient,
    this.color,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? AppColors.surface) : null,
          gradient: gradient,
          borderRadius: br,
          border: gradient == null ? Border.all(color: AppColors.border) : null,
          boxShadow: !AppColors.dark && gradient == null
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Widget? center;
  final Color? track;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.center,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => CustomPaint(
          painter: _RingPainter(v, stroke, track ?? AppColors.border),
          child: Center(
            child: center ?? Text('${(v * 100).round()}%', style: display(size * 0.24)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color track;
  _RingPainter(this.v, this.stroke, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final bg = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    if (v <= 0) return;
    final fg = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF22D3EE), Color(0xFF7C5CFF), Color(0xFFF472B6), Color(0xFF22D3EE)],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.stroke != stroke || old.track != track;
}

class GradientBar extends StatelessWidget {
  final double value;
  final double height;
  const GradientBar({super.key, required this.value, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: AppColors.border,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => FractionallySizedBox(
            widthFactor: v,
            child: Container(decoration: const BoxDecoration(gradient: AppColors.gradient)),
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final Gradient gradient;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
    this.gradient = AppColors.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
        else if (icon != null)
          Icon(icon, color: Colors.white, size: 20),
        if (loading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
    return Opacity(
      opacity: enabled || loading ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6))
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  const GhostButton({super.key, required this.label, this.icon, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.text;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, size: 18, color: c),
      label: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(children: [
        Expanded(
          child: Text(text.toUpperCase(),
              style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(28)),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: display(20)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.45)),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ]),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 40});

  static const _palettes = [
    [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
    [Color(0xFFF472B6), Color(0xFF7C5CFF)],
    [Color(0xFF34D399), Color(0xFF22D3EE)],
    [Color(0xFFFBBF24), Color(0xFFF472B6)],
  ];

  @override
  Widget build(BuildContext context) {
    final p = _palettes[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length];
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: p, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(initial, style: display(size * 0.42, color: Colors.white)),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 5)],
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: builder(ctx),
      ),
    ),
  );
}

/// One action in a long-press options sheet.
class SheetAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const SheetAction(this.icon, this.label, this.onTap, {this.danger = false});
}

Future<void> showOptionsSheet(BuildContext context, {String? title, required List<SheetAction> actions}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(title,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted)),
            ),
          for (final a in actions)
            ListTile(
              leading: Icon(a.icon, color: a.danger ? AppColors.danger : AppColors.text),
              title: Text(a.label,
                  style: TextStyle(
                      color: a.danger ? AppColors.danger : AppColors.text, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onTap: () {
                Navigator.pop(ctx);
                a.onTap();
              },
            ),
        ]),
      ),
    ),
  );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: display(18)),
      content: Text(message, style: TextStyle(color: AppColors.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action, style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return r ?? false;
}

class Loader extends StatelessWidget {
  const Loader({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
}
