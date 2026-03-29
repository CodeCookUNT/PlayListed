import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _db = FirebaseFirestore.instance;
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'playlisted_messages',
    "Playlist'd Messages",
    description: 'Push notifications for messages and friend requests.',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> initializePushNotifications() async {
    if (_initialized || kIsWeb) return;

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((_) {});

    await _messaging.getInitialMessage();

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    _initialized = true;
  }

  Future<void> syncTokenForCurrentUser() async {
    if (kIsWeb) return;

    final token = await _messaging.getToken();
    await _saveToken(token);
  }

  Future<void> _saveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null || token.isEmpty) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? (message.data['title'] as String?);
    final body = notification?.body ?? (message.data['body'] as String?);

    if (title == null && body == null) return;

    await _localNotifications.show(
      notification.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
    );
  }

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

class NotificationBootstrap extends StatefulWidget {
  const NotificationBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<NotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await NotificationService.instance.syncTokenForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
