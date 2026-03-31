import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _db = FirebaseFirestore.instance;

  Future<void> sendMessageNotification({
    required String toUid,
    required String fromUid,
    required String fromName,
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
      'fromName': fromName,
      'convoId': convoId,
      'textPreview': previewText,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
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

  Stream<int> unreadCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
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
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
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
}

class NotificationBootstrap extends StatefulWidget {
  const NotificationBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<NotificationBootstrap> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _latestNotificationId;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _listenForForegroundNotifications();
  }

  void _listenForForegroundNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final latestDoc = snapshot.docs.first;
      final latestId = latestDoc.id;

      if (!_hydrated) {
        _latestNotificationId = latestId;
        _hydrated = true;
        return;
      }

      if (_latestNotificationId == latestId) return;
      _latestNotificationId = latestId;

      final data = latestDoc.data();
      if ((data['read'] as bool?) == true) return;

      final message = _messageForNotification(data);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    });
  }

  String _messageForNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final fromName = (data['fromName'] as String?)?.trim();

    if (type == 'friend_request') {
      return '${fromName?.isNotEmpty == true ? fromName : 'Someone'} sent you a friend request';
    }

    if (type == 'message') {
      final preview = (data['textPreview'] as String?)?.trim();
      final sender = fromName?.isNotEmpty == true ? fromName! : 'A friend';
      if (preview != null && preview.isNotEmpty) {
        return '$sender: $preview';
      }
      return 'New message from $sender';
    }

    return 'You have a new notification';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
