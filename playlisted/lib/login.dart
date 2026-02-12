import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'resetPasswordPage.dart';
import 'content_filter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final emailOrUsername = TextEditingController();
  final pass = TextEditingController();
  bool passwordVisible = false;
  bool busy = false;
  
  // Add these two animation variables
  late AnimationController _colorAnimationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    _colorAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    // Create color tween animation
    _colorAnimation = ColorTween(
      begin: const Color(0xFF1583B7),
      end: const Color(0xFF6B48FF),
    ).animate(_colorAnimationController);
  }

  Future<void> _login() async {
    setState(() => busy = true);

    final input = emailOrUsername.text.trim();
    final password = pass.text;
    String? emailToUse;

    try {
      if (input.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
            code: 'empty-fields',
            message: 'Please enter both email/username and password.');
      }

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
              code: 'user-not-found',
              message: 'No user found for that username.');
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

  @override
  void dispose() {
    _colorAnimationController.dispose();
    emailOrUsername.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _colorAnimation.value ?? const Color(0xFF1583B7),
                  (_colorAnimation.value ?? const Color(0xFF1583B7))
                      .withOpacity(0.7),
                  Colors.white,
                ],
              ),
            ),
            child: Center(
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
                        TextField(
                          controller: emailOrUsername,
                          decoration: const InputDecoration(
                            labelText: 'Username or Email',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: pass,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                passwordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => passwordVisible = !passwordVisible,
                              ),
                            ),
                          ),
                          obscureText: !passwordVisible,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: busy ? null : _login,
                          child: busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(),
                                )
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpPage(),
                            ),
                          ),
                          child: const Text('Create an account'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResetPasswordPage(),
                            ),
                          ),
                          child: const Text('Forgot Password?'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
}


class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirmPass = TextEditingController();
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;
  bool busy = false;
  bool usernameError = false;
  bool fnameError = false;
  bool lnameError = false;
  bool emailError = false;
  
  late AnimationController _colorAnimationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    _colorAnimationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    // Create color tween animation
    _colorAnimation = ColorTween(
      begin: const Color(0xFF1583B7),
      end: const Color(0xFF6B48FF),
    ).animate(_colorAnimationController);
  }

  bool strongPassCheck(String password) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'\d').hasMatch(password);
    final hasSymbol = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    return password.length >= 8 &&
        hasUppercase &&
        hasNumber &&
        hasSymbol;
  }

  Future<void> _create() async {
    setState(() => busy = true);

    try {
      final uname = username.text.trim();
      final fname = firstName.text.trim();
      final lname = lastName.text.trim();
      final mail = email.text.trim();
      final password = pass.text;

      final usernameHasExplicit = ExplicitContentFilter.containsExplicitContent(uname);
      final fnameHasExplicit = ExplicitContentFilter.containsExplicitContent(fname);
      final lnameHasExplicit = ExplicitContentFilter.containsExplicitContent(lname);
      final emailHasExplicit = ExplicitContentFilter.containsExplicitContent(mail);

      if (mounted) setState(() {
        usernameError = usernameHasExplicit;
        fnameError = fnameHasExplicit;
        lnameError = lnameHasExplicit;
        emailError = emailHasExplicit;
      });

      if (usernameHasExplicit || fnameHasExplicit || lnameHasExplicit || emailHasExplicit) {
        if (mounted) setState(() => busy = false);
        return;
      }

      if (password != confirmPass.text) {
        if (mounted) setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords Do Not Match.')),
        );
        return;
      }

      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );

      final user = cred.user;

      if (user != null) {
        await user.updateDisplayName(uname);
        await user.reload();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
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
    _colorAnimationController.dispose();
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
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Create account')),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _colorAnimation.value ?? const Color(0xFF1583B7),
                  _colorAnimation.value?.withOpacity(0.7) ?? const Color(0xFF1583B7).withOpacity(0.7),
                  Colors.white,
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 8,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 473),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: username,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            errorText: usernameError ? 'Username contains explicit content.' : null,
                          ),
                          onChanged: (value) {
                            final trimmed = value.trim();
                            final hasExplicit = ExplicitContentFilter.containsExplicitContent(trimmed);
                            setState(() {
                              usernameError = hasExplicit;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: firstName,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            errorText: fnameError ? 'First name contains explicit content.' : null,
                          ),
                          onChanged: (value) {
                            final hasExplicit = ExplicitContentFilter.containsExplicitContent(value.trim());
                            setState(() {
                              fnameError = hasExplicit;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: lastName,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            errorText: lnameError ? 'Last name contains explicit content.' : null,
                          ),
                          onChanged: (value) {
                            final hasExplicit = ExplicitContentFilter.containsExplicitContent(value.trim());
                            setState(() {
                              lnameError = hasExplicit;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: email,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: emailError ? 'Email contains explicit content.' : null,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            final hasExplicit = ExplicitContentFilter.containsExplicitContent(value.trim());
                            setState(() {
                              emailError = hasExplicit;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: pass,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helper: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('At Least 8 Characters'),
                                  Text('One Uppercase Letter'),
                                  Text('One Number'),
                                  Text('One Special Symbol'),
                                ],
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(passwordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() =>
                                  passwordVisible = !passwordVisible),
                            ),
                          ),
                          obscureText: !passwordVisible,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPass,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            suffixIcon: IconButton(
                              icon: Icon(confirmPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() =>
                                  confirmPasswordVisible =
                                      !confirmPasswordVisible),
                            ),
                          ),
                          obscureText: !confirmPasswordVisible,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: busy ? null : _create,
                          child: busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator())
                              : const Text('Finish'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}