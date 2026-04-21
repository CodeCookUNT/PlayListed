import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService._();
  static final AccountDeletionService instance = AccountDeletionService._();
  static const Duration _cleanupTimeout = Duration(seconds: 12);
  static const Duration _reauthTimeout = Duration(seconds: 20);
  static const Duration _authDeleteTimeout = Duration(seconds: 20);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

    final uid = user.uid;
    final userDoc = await _db.collection('users').doc(uid).get();
    final username = (userDoc.data()?['username'] as String?)?.toLowerCase();

    try {
      await _cleanupFirestoreData(uid: uid, username: username).timeout(_cleanupTimeout);
    } on TimeoutException {
      // Do not block auth deletion if data cleanup is slow on mobile networks/devices.
    } on FirebaseException catch (e) {
      if (!_isSkippableCleanupError(e)) {
        rethrow;
      }
      // Continue to auth deletion even if some Firestore cleanup queries are blocked.
    }

    await user.delete().timeout(_authDeleteTimeout);
    await _auth.signOut();
  }

  Future<void> _cleanupFirestoreData({
    required String uid,
    required String? username,
  }) async {
    // Keep on-device account cleanup bounded and fast.
    // Cross-user/global cleanups are intentionally omitted from the client path
    // because they are costly on phones and can trigger ANRs/disconnects.
    // They should be handled by a backend/admin cleanup job.
    final userDocRef = _db.collection('users').doc(uid);
    await _bestEffortDeleteCollection(userDocRef.collection('ratings'));
    await _bestEffortDeleteCollection(userDocRef.collection('recommendations'));
    await _bestEffortDeleteCollection(userDocRef.collection('friends'));
    await _bestEffortDeleteCollection(userDocRef.collection('incoming_requests'));
    await _bestEffortDeleteCollection(userDocRef.collection('outgoing_requests'));
    await _bestEffortDeleteCollection(userDocRef.collection('co_liked'));
    await _bestEffortDeleteDocsFromQuery(
      _db.collection('song_reviews').where('userId', isEqualTo: uid),
    );

    await userDocRef.delete().catchError((_) {});

    if (username != null && username.isNotEmpty) {
      await _db.collection('usernames').doc(username).delete().catchError((_) {});
    }
  }

  Future<void> _bestEffortDeleteCollection(
    CollectionReference<Map<String, dynamic>> colRef,
  ) async {
    try {
      await _deleteCollection(colRef);
    } on FirebaseException catch (e) {
      if (!_isSkippableCleanupError(e)) {
        rethrow;
      }
    }
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> colRef) async {
    while (true) {
      final snapshot = await colRef.limit(200).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDocsFromQuery(
    Query<Map<String, dynamic>> query, {
    List<String> deleteSubcollections = const [],
  }) async {
    while (true) {
      final snapshot = await query.limit(100).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      for (final doc in snapshot.docs) {
        for (final subcollection in deleteSubcollections) {
          await _deleteCollection(doc.reference.collection(subcollection));
        }
      }

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _bestEffortDeleteDocsFromQuery(
    Query<Map<String, dynamic>> query, {
    List<String> deleteSubcollections = const [],
  }) async {
    try {
      await _deleteDocsFromQuery(
        query,
        deleteSubcollections: deleteSubcollections,
      );
    } on FirebaseException catch (e) {
      if (!_isSkippableCleanupError(e)) {
        rethrow;
      }
      // Ignore expected Firestore cleanup failures so auth deletion can complete.
    }
  }

  bool _isSkippableCleanupError(FirebaseException e) {
    return e.code == 'permission-denied' ||
        e.code == 'failed-precondition' ||
        e.code == 'not-found';
  }
}
