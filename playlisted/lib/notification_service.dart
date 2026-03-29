import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _db = FirebaseFirestore.instance;

  Future<void> sendMessageNotification({
    required String toUid,
    required String fromUid,
    required String convoId,
    required String previewText,
  }) async {

    await _db
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .add({
      'type': 'message',
      'fromUid': fromUid,
      'convoId': convoId,
      'textPreview': previewText,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Stream<int> unreadCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markConversationNotificationsRead({
    required String uid,
    required String convoId,
  }) async {

    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('convoId', isEqualTo: convoId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();

    for (var doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }
  Stream<List<Map<String, dynamic>>> notificationsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
        );
  }
  Future<void> markNotificationRead({
    required String uid,
    required String notificationId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
  Future<void> sendFriendRequestNotification({
    required String toUid,
    required String fromUid,
    required String fromName,
  }) async {
    await _db
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .add({
      'type': 'friend_request',
      'fromUid': fromUid,
      'fromName': fromName,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}