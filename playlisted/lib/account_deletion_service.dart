import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  AccountDeletionService._();
  static final AccountDeletionService instance = AccountDeletionService._();
  static const Duration _cleanupTimeout = Duration(seconds: 12);

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
    await user.reauthenticateWithCredential(credential);
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
      if (e.code != 'permission-denied') {
        rethrow;
      }
      // Continue to auth deletion even if some Firestore locations are blocked by rules.
    }

    await user.delete();
    await _auth.signOut();
  }

  Future<void> _cleanupFirestoreData({
    required String uid,
    required String? username,
  }) async {
    await Future.wait([
      _deleteCollection(_db.collection('users').doc(uid).collection('ratings')),
      _deleteCollection(_db.collection('users').doc(uid).collection('recommendations')),
      _deleteCollection(_db.collection('users').doc(uid).collection('friends')),
      _deleteCollection(_db.collection('users').doc(uid).collection('incoming_requests')),
      _deleteCollection(_db.collection('users').doc(uid).collection('outgoing_requests')),
      _deleteCollection(_db.collection('users').doc(uid).collection('co_liked')),
      _deleteDocsFromQuery(_db.collection('song_reviews').where('userId', isEqualTo: uid)),
      // Best-effort cleanups for shared/cross-user areas.
      // These may be blocked by security rules; do not stop auth deletion if so.
      _bestEffortDeleteDocsFromQuery(
        _db.collection('conversations').where('participants', arrayContains: uid),
        deleteSubcollections: const ['messages'],
      ),
      _bestEffortDeleteDocsFromQuery(
        _db.collectionGroup('friends').where('friendUid', isEqualTo: uid),
      ),
      _bestEffortDeleteDocsFromQuery(
        _db.collectionGroup('incoming_requests').where('fromUid', isEqualTo: uid),
      ),
      _bestEffortDeleteDocsFromQuery(
        _db.collectionGroup('outgoing_requests').where('toUid', isEqualTo: uid),
      ),
    ]);

    await _db.collection('users').doc(uid).delete();

    if (username != null && username.isNotEmpty) {
      await _db.collection('usernames').doc(username).delete().catchError((_) {});
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
      if (e.code != 'permission-denied') {
        rethrow;
      }
      // Ignore permission-denied here so account auth deletion can still complete.
    }
  }
}
