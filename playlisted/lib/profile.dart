import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profilefunctions.dart';

class ProfilePage extends StatelessWidget {
  final String uid;
  const ProfilePage({super.key, required this.uid});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profileFunctions = ProfileFunctions.instance;
    final isMe = FirebaseAuth.instance.currentUser?.uid == uid;
    if (user == null) {
      return Center(
        child: Text('Not logged in'),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (userSnap.hasError) {
          return Center(child: Text('Error loading user: ${userSnap.error}'));
        }

        final data = userSnap.data?.data() ?? {};
        final displayName = (data['username'] as String?) ??
            (data['displayName'] as String?) ??
            (data['email'] as String?) ??
            'Unknown';
        final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
        final statsTitle = isMe ? 'Your Statistics' : "$displayName's Statistics";

        return StreamBuilder<QuerySnapshot>(
      stream: profileFunctions.ratingsStream(uid: uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading profile: ${snapshot.error}'));
        }

        // Get user stats from ProfileFunctions
        final stats = snapshot.hasData 
            ? profileFunctions.getUserStats(snapshot.data!)
            : {'totalReviews': 0, 'averageRating': 0.0, 'favoriteSongs': []};
        
        final totalReviews = stats['totalReviews'] as int;
        final averageRating = stats['averageRating'] as double;
        final favoriteSongs = stats['favoriteSongs'] as List<Map<String, dynamic>>;

        //get text reviews from profilefunctions
        final textReviews = snapshot.hasData
            ? profileFunctions.getTextReviews(snapshot.data!)
            : <Map<String, dynamic>>[];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile Picture and Email Section
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 40),
            
            // Stats Cards
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statsTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // Total Reviews
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.rate_review,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Total Songs Rated:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$totalReviews',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 20),
                    Divider(),
                    SizedBox(height: 20),
                    
                    // Average Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Average Rating:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Visual star rating
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final starValue = index + 1;
                          IconData icon;

                          if (averageRating >= starValue) {
                            icon = Icons.star;
                          } else if (averageRating >= starValue - 0.5) {
                            icon = Icons.star_half;
                          } else {
                            icon = Icons.star_border;
                          }

                          return Icon(
                            icon,
                            size: 32,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Favorite Songs Section (5 star ratings)
            if (favoriteSongs.isNotEmpty) ...[
              SizedBox(height: 20),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          
                          SizedBox(width: 8),
                          Text(
                            isMe ? 'Your Favorite Songs:' : "$displayName's Favorite Songs:",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ...favoriteSongs.map((song) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              // Album artwork or icon
                              if (song['albumImageUrl'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    song['albumImageUrl'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey,
                                        child: Icon(Icons.music_note, color: Colors.white),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(Icons.music_note),
                                ),
                              SizedBox(width: 12),
                              // Song info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      song['artists'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Star icon
                              Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            // your reviews section(any song with a text review)
            if (textReviews.isNotEmpty) ...[
              SizedBox(height: 20),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? 'Your Reviews:' : "$displayName's Reviews:",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 16),

                      ...textReviews.map((r) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Album image
                              if (r['albumImageUrl'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    r['albumImageUrl'],
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(Icons.music_note),
                                ),

                              SizedBox(width: 12),

                              // Name, artist, and text review
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['name'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      r['artists'] ?? 'Unknown Artist',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      r['review'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Star rating
                              Column(
                                children: [
                                  Row(
                                    children: List.generate(5, (i) {
                                      final rr = (r['rating'] as double?) ?? 0.0;
                                      return Icon(
                                        i < rr ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 16,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            ],
          );
      },
    );
      },
    );
  }
}
