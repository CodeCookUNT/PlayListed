import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final emailOrUsername = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool passwordVisible = false;
  bool busy = false;

  Future<void> _login() async {
    setState(() => busy = true);

    final input = emailOrUsername.text.trim();
    String? emailToUse;

    try {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      final isEmail = emailRegex.hasMatch(input);

      if (isEmail) {
        emailToUse = input;
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(input.toLowerCase())
            .get();

        if (!doc.exists) {
          throw FirebaseAuthException(
              code: 'user-not-found', message: 'No user found for that username.');
        }

        emailToUse = doc['email'];
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailToUse!,
        password: pass.text,
      );

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login error: ${e.code}')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
  final input = emailOrUsername.text.trim();
  if (input.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter your email first')),
    );
    return;
  }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: input);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $input')),
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
    emailOrUsername.dispose();
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
              controller: emailOrUsername,
              decoration: const InputDecoration(labelText: 'Username or Email'),
            ),
            TextField(
              controller: pass,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                icon: Icon(
                  passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => passwordVisible = !passwordVisible),
                ),
              ),
                obscureText: !passwordVisible,
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
  final username = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirmPass = TextEditingController();
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;
  bool busy = false;

  bool strongPassCheck(String password) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSymbol = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    return password.length >= 8 && hasUppercase && hasNumber && hasSymbol;
  }

  Future<void> _create() async {
    setState(() => busy = true);
    try {
      final uname = username.text.trim();
      final fname = firstName.text.trim();
      final lname = lastName.text.trim();
      final mail = email.text.trim();
      final password = pass.text;

      if (!strongPassCheck(password)) {
        if (mounted) setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password Must Follow Requirements Guideline.')),
          );
        return;
      }

      if (password != confirmPass.text) {
        if (mounted) setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords Do Not Match.')),
        );
        return;
      }

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );

      final user = cred.user;
      if(user != null){
        await user.updateDisplayName(uname);
        await user.reload();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': uname,
          'firstName': fname,
          'lastName': lname,
          'email': mail,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(uname.toLowerCase())
            .set({
          'uid': user.uid,
          'email': mail,
        });
      }

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
    username.dispose();
    email.dispose();
    pass.dispose();
    confirmPass.dispose();
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
            TextField(controller: username, decoration: const InputDecoration(labelText: 'User Name')),
            TextField(controller: firstName, decoration: const InputDecoration(labelText: 'First Name')),
            TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Last Name')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField( 
              controller: pass,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'Must Be At Least 8 Characters and Include One Uppercase Letter, Number, and Special Symbol.',
                suffixIcon: IconButton(
                  icon: Icon(
                    passwordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => passwordVisible = !passwordVisible),
                ),
              ),
              obscureText: !passwordVisible,
            ),
            TextField(
              controller: confirmPass,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    confirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => confirmPasswordVisible = !confirmPasswordVisible),
                ),
              ),
              obscureText: !confirmPasswordVisible,
            ),      
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