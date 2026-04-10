import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'friends.dart';

///A widget that displays which friends have liked a specific track.
///shows a message with friend names when viewing a song that friends also like.
class FriendLikesWidget extends StatelessWidget {
  final String trackId;
  final String trackName;

  const FriendLikesWidget({
    super.key,
    required this.trackId,
    required this.trackName,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FriendsService.instance.friendsStream(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!friendsSnapshot.hasData || friendsSnapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final friends = friendsSnapshot.data!;

        return FutureBuilder<List<String>>(
          future: _getFriendsWhoLikedTrack(friends, trackId),
          builder: (context, likedSnapshot) {
            if (likedSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            if (!likedSnapshot.hasData || likedSnapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final friendNames = likedSnapshot.data!;
            return _buildFriendLikesDisplay(context, friendNames);
          },
        );
      },
    );
  }

  ///queries firestore to find which friends have liked this track
  Future<List<String>> _getFriendsWhoLikedTrack(
    List<Map<String, dynamic>> friends,
    String trackId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final likedByFriends = <String>[];

    for (final friend in friends) {
      final friendUid = friend['friendUid'] as String?;
      if (friendUid == null) continue;

      try {
        final ratingDoc = await firestore
            .collection('users')
            .doc(friendUid)
            .collection('ratings')
            .doc(trackId)
            .get();

        if (ratingDoc.exists && ((ratingDoc.data()?['favorite'] as bool?) == true)) {
          //final rating = ratingDoc.data()?['rating'] as num?;
          // If friend has a rating > 0, they have liked the track
          final friendName = friend['friendName'] as String? ?? 'Friend';
          likedByFriends.add(friendName);
          
        }
      } catch (e) {
        print('Error checking friend rating: $e');
      }
    }

    return likedByFriends;
  }

  /// Builds a nice display widget showing which friends liked the track
  Widget _buildFriendLikesDisplay(
    BuildContext context,
    List<String> friendNames,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String friendText;
    if (friendNames.length == 1) {
      friendText = '${friendNames[0]} also likes this song!';
    } else if (friendNames.length == 2) {
      friendText = '${friendNames[0]} and ${friendNames[1]} like this song!';
    } else {
      final others = friendNames.length - 2;
      friendText =
          '${friendNames[0]}, ${friendNames[1]}, and $others more like this song!';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8), //<-- adjust Y-axis margin
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: (isDark ? Colors.blue[900] : Colors.blue[50])?.withOpacity(0.8),
        border: Border.all(
          color: theme.primaryColor,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            color: theme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              friendText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.blue[100] : Colors.blue[900],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
