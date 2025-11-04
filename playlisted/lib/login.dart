import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;

  Future<void> _login() async {
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text,
      );
      // The AuthGate function will switch you the homepage in main.dart
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error: ${e.code} – ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'Auth error: ${e.code}')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
  final emailText = email.text.trim();
  if (emailText.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter your email first')),
    );
    return;
  }

  try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailText);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $emailText')),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to send reset email')),
      );
    }
  }

  //clear email and password variables after use
  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: busy ? null : _login,
              child: busy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator())
                  : const Text('Login'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpPage()),
              ),
              child: busy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator())
                  : const Text('Create an account'),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: resetPassword,
                child: busy
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator())
                    : const Text('Forgot Password?'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;

  Future<void> _create() async {
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: pass.text,
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth error: ${e.code} – ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message ?? 'Auth error: ${e.code}')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: firstName, decoration: const InputDecoration(labelText: 'First Name')),
            TextField(controller: lastName,  decoration: const InputDecoration(labelText: 'Last Name')),
            TextField(controller: email,     decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            TextField(controller: pass,      decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: busy ? null : _create,
              child: busy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator())
                  : const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}