import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// Make sure a profile exists for the logged-in user.
  Future<void> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _db.collection('users').doc(user.uid);

    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'username': user.displayName,
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stream of accepted friends for the current user.
  Stream<List<Map<String, dynamic>>> friendsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(_uid)
        .collection('friends')
        .where('status', isEqualTo: 'accepted')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Add a friend by their email (simple v1, no requests, just mutual friendship).
  Future<void> addFriendByEmail(String email) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('You must be logged in to add friends.');
    }

    final input = email.trim().toLowerCase();
    if (input.isEmpty) {
      throw Exception('Enter a username or email.');
    }
    if (current.email != null && current.email!.toLowerCase() == input) {
      throw Exception('You cannot add yourself.');
    }

    QuerySnapshot<Map<String, dynamic>> query;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    final isEmail = emailRegex.hasMatch(input);

    if (isEmail) {
      query = await _db
          .collection('users')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();
    } else {
      final unameDoc = await _db.collection('usernames').doc(input).get();
      if (!unameDoc.exists) {
        throw Exception('No user found with that username or email.');
      }
      final friendUid = unameDoc['uid'];

      query = await _db
          .collection('users')
          .where('uid', isEqualTo: friendUid)
          .limit(1)
          .get();
    }

    if (query.docs.isEmpty) {
      throw Exception('No user found.');
    }

    final otherDoc = query.docs.first;
    final otherData = otherDoc.data();
    final friendUid = otherDoc.id;

    final friendName =
        (otherData['username'] as String?) ??  // prefer username
        (otherData['displayName'] as String?) ??
        (otherData['email'] as String?) ??
        'Friend';

    final friendPhotoUrl = otherData['photoUrl'] as String?;

    final now = Timestamp.now();

    final myRef = _db
        .collection('users')
        .doc(current.uid)
        .collection('friends')
        .doc(friendUid);

    final theirRef = _db
        .collection('users')
        .doc(friendUid)
        .collection('friends')
        .doc(current.uid);

    final batch = _db.batch();

    batch.set(myRef, {
      'friendUid': friendUid,
      'friendName': friendName,
      'friendPhotoUrl': friendPhotoUrl,
      'status': 'accepted',
      'createdAt': now,
    }, SetOptions(merge: true));

    batch.set(theirRef, {
      'friendUid': current.uid,
      'friendName': current.displayName ??
          (current.email?.split('@').first ?? 'You'),
      'friendPhotoUrl': current.photoURL,
      'status': 'accepted',
      'createdAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}