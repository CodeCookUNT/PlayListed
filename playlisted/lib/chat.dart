import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'content_filter.dart';

class ChatPage extends StatefulWidget {
  final String friendUid;
  final String friendName;

  const ChatPage({
    super.key,
    required this.friendUid,
    required this.friendName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _controller = TextEditingController();

  String get _myUid => _auth.currentUser!.uid;

  String get _convoId {
    final list = [_myUid, widget.friendUid]..sort();
    return '${list[0]}_${list[1]}';
  }

  @override
  void initState() {
    super.initState();
    _ensureConvoExists();
  }

  Future<void> _ensureConvoExists() async {
  final convoRef = _db.collection('conversations').doc(_convoId);
    try {
      await convoRef.set({
        'participants': [_myUid, widget.friendUid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint("ensureConvoExists failed: ${e.code} ${e.message}");
    }
  }

  CollectionReference<Map<String, dynamic>> get _messagesCol =>
      _db.collection('conversations').doc(_convoId).collection('messages');

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final convoRef = _db.collection('conversations').doc(_convoId);

    await convoRef.set({
      'participants': [_myUid, widget.friendUid],
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': text,
      'lastSenderId': _myUid,
    }, SetOptions(merge: true));
      
    await _messagesCol.add({
      'senderId': _myUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesCol
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = data['senderId'] == _myUid;
                    final text = data['text'] as String? ?? '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}