import 'package:flutter/material.dart';
import 'friends.dart';
import 'chat.dart';
import 'profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _emailController = TextEditingController();
  bool _isAdding = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addFriend() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter an email.');
      return;
    }

    setState(() {
      _isAdding = true;
      _error = null;
    });

    try {
      await FriendsService.instance.sendFriendRequest(email);
      _emailController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add friend by email section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Send Request by Username or email',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addFriend(),
                ),
              ),
              const SizedBox(width: 8),
              _isAdding
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.person_add),
                      onPressed: _addFriend,
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_box),
                      tooltip: 'Friend requests',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
                        );
                     },
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Friends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // Friends list
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FriendsService.instance.friendsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Friends load error:\n${snapshot.error}'),
                );
              }

              final friends = snapshot.data ?? [];

              if (friends.isEmpty) {
                return const Center(
                  child: Text(
                    'No friends yet.\nAdd someone by their Username or email to start chatting.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                itemCount: friends.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  final friendUid = friend['friendUid'] as String;
                  final name = friend['friendName'] as String? ?? 'Unknown';

                  return ListTile(
                    leading: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('users').doc(friendUid).snapshots(),
                      builder: (context, snap) {
                        final u = snap.data?.data();

                        final int? cachedColor = friend['friendAvatarColor'] as int?;
                        final String? cachedIconKey = friend['friendAvatarIcon'] as String?;

                        final int avatarColorInt =
                            cachedColor ??
                            (u?['avatarColor'] as int?) ??
                            Theme.of(context).colorScheme.primary.toARGB32();

                        final String? avatarIconKey =
                            cachedIconKey ?? (u?['avatarIcon'] as String?);

                        final avatarIcon = iconFromKey(avatarIconKey);

                        if (cachedColor == null && u != null && u['avatarColor'] != null) {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('friends')
                              .doc(friendUid)
                              .set({
                            'friendAvatarColor': u['avatarColor'],
                            'friendAvatarIcon': u['avatarIcon'],
                          }, SetOptions(merge: true));
                        }

                        return CircleAvatar(
                          backgroundColor: Color(avatarColorInt),
                          child: Icon(avatarIcon, color: Colors.white),
                        );
                      },
                    ),
                    title: Text(name),
                    subtitle: const Text('Tap to open chat'),
                    trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.account_box),
                        tooltip: 'View profile',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: Text("$name's Profile")),
                                body: ProfilePage(uid: friendUid),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        tooltip: 'Remove friend',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Remove friend?'),
                              content: Text('Remove $name from your friends list?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                              ),
                            ],
                           ),
                      );

                      if (confirm == true) {
                        await FriendsService.instance.removeFriend(friendUid);
                      }
                    },
                    ),
                    ],
                  ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            friendUid: friendUid,
                            friendName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
// TODO Add friend storys feature / a way to view friends favoirtes songs and reviws
// The friends story and profile view will need a new UI elements to work on the friends page

class FriendRequestsPanel extends StatelessWidget {
  const FriendRequestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Friend Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // ---- Incoming requests ----
            const Text('Incoming',
                style: TextStyle(fontWeight: FontWeight.w600)),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FriendsService.instance.incomingRequestsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  );
                }

                final incoming = snapshot.data ?? [];
                if (incoming.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No incoming requests'),
                  );
                }

                return Column(
                  children: incoming.map((req) {
                    final requestId = req['requestId'] as String;
                    final fromName =
                        (req['fromName'] as String?) ?? 'Unknown';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(fromName),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () {
                              FriendsService.instance
                                  .declineRequest(requestId);
                            },
                            child: const Text('Decline'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              FriendsService.instance
                                  .acceptRequest(requestId);
                            },
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const Divider(),

            // ---- Outgoing requests ----
            const Text('Outgoing',
                style: TextStyle(fontWeight: FontWeight.w600)),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FriendsService.instance.outgoingRequestsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  );
                }

                final outgoing = snapshot.data ?? [];
                if (outgoing.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No outgoing requests'),
                  );
                }

                return Column(
                  children: outgoing.map((req) {
                    final requestId = req['requestId'] as String;
                    final toName =
                        (req['toName'] as String?) ?? 'Unknown';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(toName),
                      subtitle: const Text('Pending'),
                      trailing: TextButton(
                        onPressed: () {
                          FriendsService.instance
                              .cancelRequest(requestId);
                        },
                        child: const Text('Cancel'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Requests')),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: const [
          FriendRequestsPanel(),
        ],
      ),
    );
  }
}

IconData iconFromKey(String? key) {
  switch (key) {
    case 'music_note':
      return Icons.music_note;
    case 'music_note_outlined':
      return Icons.music_note_outlined;
    case 'library_music':
      return Icons.library_music;
    case 'library_music_outlined':
      return Icons.library_music_outlined;
    case 'queue_music':
      return Icons.queue_music;
    case 'album':
      return Icons.album;
    case 'album_outlined':
      return Icons.album_outlined;
    case 'graphic_eq':
      return Icons.graphic_eq;
    default:
      return Icons.music_note;
  }
}