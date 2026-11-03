import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/db.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = false;
  bool _loading = false;
  bool _hide = true;
  String? _error;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      if (_signup) {
        if (_name.text.trim().isEmpty) {
          setState(() => _error = 'Please enter your name.');
          return;
        }
        final cred = await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text);
        await cred.user!.updateDisplayName(_name.text.trim());
        await Db.ensureProfile();
      } else {
        await auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Type your email above, then tap "Forgot password".');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) toast(context, 'Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(top: -120, right: -80, child: _blob(AppColors.primary, 300)),
        Positioned(top: 180, left: -120, child: _blob(AppColors.accent, 260)),
        SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset('assets/logo.png', width: 84, height: 84, filterQuality: FilterQuality.high),
              ),
              SizedBox(height: 28),
              Text('StudyCircle', style: display(38)),
              SizedBox(height: 10),
              Text(
                'Your self-made university.\nRoadmaps, classmates, class alarms, exams and an AI tutor — so learning never depends on mood.',
                style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.5),
              ),
              SizedBox(height: 36),
              if (_signup) ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
                ),
                SizedBox(height: 12),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: _hide,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Password (6+ characters)',
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 14),
                Text(_error!, style: TextStyle(color: AppColors.danger)),
              ],
              SizedBox(height: 24),
              GradientButton(
                label: _signup ? 'Create account' : 'Sign in',
                icon: _signup ? Icons.rocket_launch_rounded : Icons.login_rounded,
                loading: _loading,
                onPressed: _submit,
              ),
              SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(
                  onPressed: () => setState(() {
                    _signup = !_signup;
                    _error = null;
                  }),
                  child: Text(_signup ? 'I already have an account' : 'New here? Create an account'),
                ),
                if (!_signup)
                  TextButton(
                    onPressed: _reset,
                    child: Text('Forgot password', style: TextStyle(color: AppColors.muted)),
                  ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _blob(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0)]),
          ),
        ),
      );
}
