import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService._();
  static final AccountDeletionService instance = AccountDeletionService._();
  static const Duration _reauthTimeout = Duration(seconds: 20);
  static const Duration _authDeleteTimeout = Duration(seconds: 20);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> reauthenticateAndDelete({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No logged-in user found.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('This account does not have an email for re-authentication.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user
        .reauthenticateWithCredential(credential)
        .timeout(_reauthTimeout);
    await deleteCurrentUserAccountAndData();
  }

  Future<void> deleteCurrentUserAccountAndData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No logged-in user found.');
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final username = userDoc.data()?['username'] as String?;

    await _db.collection('deletion_requests').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'username': username,
      'status': 'queued',
      'requestedAt': FieldValue.serverTimestamp(),
      'source': 'client',
    }, SetOptions(merge: true));

    // Keep on-device deletion minimal to avoid ANRs on lower-end phones.
    // Firestore cleanup is handled by an external admin cleanup worker.
    await user.delete().timeout(_authDeleteTimeout);
    await _auth.signOut();
  }
}
