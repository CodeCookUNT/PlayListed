import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailOrUsername = TextEditingController();
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _emailOrUsername.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(s.trim());
  }

  Future<String?> _resolveToEmail(String input) async {
    final trimmed = input.trim();
    if (_looksLikeEmail(trimmed)) return trimmed;

    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(trimmed.toLowerCase())
        .get();

    if (!doc.exists) return null;
    return doc.data()?['email'] as String?;
  }

  Future<void> _sendReset() async {
    final input = _emailOrUsername.text.trim();

    setState(() {
      _errorText = null;
      _busy = true;
    });

      if (input.isEmpty) {
        setState(() => _errorText = 'Please enter your email or username.');
        return;
      }

      final email = await _resolveToEmail(input);
      if (email != null && email.isNotEmpty) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account is associated with that email or username, a reset link has been sent.',
          ),
        ),
      );
      Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your email or username and we’ll send a reset link.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailOrUsername,
                    decoration: InputDecoration(
                      labelText: 'Email or Username',
                      errorText: _errorText,
                    ),
                    onSubmitted: (_) => _busy ? null : _sendReset(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _busy ? null : _sendReset,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('Send Reset Link'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
