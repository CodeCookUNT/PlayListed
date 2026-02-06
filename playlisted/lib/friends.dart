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

    Future<void> sendFriendRequest(String input) async {
    final current = _auth.currentUser;
    if (current == null) {
      throw Exception('You must be logged in to add friends.');
    }

    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw Exception('Enter a username or email.');
    }

    // lookup user by email OR username (same logic as addFriendByEmail)
    QuerySnapshot<Map<String, dynamic>> query;

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    final isEmail = emailRegex.hasMatch(normalized);

    if (isEmail) {
      query = await _db
          .collection('users')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
    } else {
      final unameDoc = await _db.collection('usernames').doc(normalized).get();
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

    if (friendUid == current.uid) {
      throw Exception('You cannot add yourself.');
    }

    // prevent duplicate requests
    final existingOutgoing = await _db
        .collection('users')
        .doc(current.uid)
        .collection('outgoing_requests')
        .doc(friendUid)
        .get();
    if (existingOutgoing.exists) return;

    final existingIncoming = await _db
    .collection('users')
    .doc(current.uid)
    .collection('incoming_requests')
    .doc(friendUid)
    .get();

    if (existingIncoming.exists) {
      throw Exception('They already sent you a request — check Incoming requests.');
    }
    // prevent requesting someone you're already friends with
    final existingFriend = await _db
        .collection('users')
        .doc(current.uid)
        .collection('friends')
        .doc(friendUid)
        .get();
    if (existingFriend.exists && existingFriend.data()?['status'] == 'accepted') {
      return;
    }

    final friendName =
        (otherData['username'] as String?) ??
        (otherData['displayName'] as String?) ??
        (otherData['email'] as String?) ??
        'Friend';

    final friendPhotoUrl = otherData['photoUrl'] as String?;

    final myName = current.displayName ??
        (current.email?.split('@').first ?? 'You');

    final now = Timestamp.now();

    final myOutgoingRef = _db
        .collection('users')
        .doc(current.uid)
        .collection('outgoing_requests')
        .doc(friendUid);

    final theirIncomingRef = _db
        .collection('users')
        .doc(friendUid)
        .collection('incoming_requests')
        .doc(current.uid);

    final batch = _db.batch();

    batch.set(myOutgoingRef, {
      'fromUid': current.uid,
      'toUid': friendUid,
      'toName': friendName,
      'toPhotoUrl': friendPhotoUrl,
      'status': 'pending',
      'createdAt': now,
    });

    batch.set(theirIncomingRef, {
      'fromUid': current.uid,
      'toUid': friendUid,
      'fromName': myName,
      'fromPhotoUrl': current.photoURL,
      'status': 'pending',
      'createdAt': now,
    });

    await batch.commit();
  }

  /// Add a friend by their email (simple v1, no requests, just mutual friendship).
  Future<void> addFriendByEmail(String email) async {
    await sendFriendRequest(email);
  }

  // Friend request features to work on

Stream<List<Map<String, dynamic>>> incomingRequestsStream() {
  final user = _auth.currentUser;
  if (user == null) return Stream.value([]);

  return _db
      .collection('users')
      .doc(_uid)
      .collection('incoming_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) {
          final data = d.data();
          return {...data, 'requestId': d.id};
        }).toList(),
      );
}

Stream<List<Map<String, dynamic>>> outgoingRequestsStream() {
  final user = _auth.currentUser;
  if (user == null) return Stream.value([]);

  return _db
      .collection('users')
      .doc(_uid)
      .collection('outgoing_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) {
          final data = d.data();
          return {...data, 'requestId': d.id};
        }).toList(),
      );
}

Future<void> acceptRequest(String requestId) async {
  final current = _auth.currentUser;
  if (current == null) return;

  final otherUid = requestId;

  final incomingRef = _db
      .collection('users')
      .doc(current.uid)
      .collection('incoming_requests')
      .doc(otherUid);

  final outgoingRef = _db
      .collection('users')
      .doc(otherUid)
      .collection('outgoing_requests')
      .doc(current.uid);

  final incomingSnap = await incomingRef.get();
  if (!incomingSnap.exists) return;

  final otherUserSnap =
      await _db.collection('users').doc(otherUid).get();
  final otherData = otherUserSnap.data() ?? {};

  final otherName =
      otherData['username'] ??
      otherData['displayName'] ??
      otherData['email'] ??
      'Friend';

  final myName = current.displayName ??
      (current.email?.split('@').first ?? 'You');

  final now = Timestamp.now();

  final myFriendRef = _db
      .collection('users')
      .doc(current.uid)
      .collection('friends')
      .doc(otherUid);

  final theirFriendRef = _db
      .collection('users')
      .doc(otherUid)
      .collection('friends')
      .doc(current.uid);

  final batch = _db.batch();

  batch.set(myFriendRef, {
    'friendUid': otherUid,
    'friendName': otherName,
    'friendPhotoUrl': otherData['photoUrl'],
    'status': 'accepted',
    'createdAt': now,
  }, SetOptions(merge: true));

  batch.set(theirFriendRef, {
    'friendUid': current.uid,
    'friendName': myName,
    'friendPhotoUrl': current.photoURL,
    'status': 'accepted',
    'createdAt': now,
  }, SetOptions(merge: true));

  batch.delete(incomingRef);
  batch.delete(outgoingRef);

  await batch.commit();
}

Future<void> declineRequest(String requestId) async {
  final current = _auth.currentUser;
  if (current == null) return;

  final otherUid = requestId;

  final incomingRef = _db
      .collection('users')
      .doc(current.uid)
      .collection('incoming_requests')
      .doc(otherUid);

  final outgoingRef = _db
      .collection('users')
      .doc(otherUid)
      .collection('outgoing_requests')
      .doc(current.uid);

  final batch = _db.batch();
  batch.delete(incomingRef);
  batch.delete(outgoingRef);
  await batch.commit();
}

Future<void> cancelRequest(String requestId) async {
  final current = _auth.currentUser;
  if (current == null) return;

  final otherUid = requestId;

  final myOutgoingRef = _db
      .collection('users')
      .doc(current.uid)
      .collection('outgoing_requests')
      .doc(otherUid);

  final theirIncomingRef = _db
      .collection('users')
      .doc(otherUid)
      .collection('incoming_requests')
      .doc(current.uid);

  final batch = _db.batch();
  batch.delete(myOutgoingRef);
  batch.delete(theirIncomingRef);
  await batch.commit();
}
}
