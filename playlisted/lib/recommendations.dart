// beginning development of recommendations algorithm, making file
import 'local_music_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';



//when building a recomendation system, we will begin with content-based filtering
//which uses track attributes to recommend similar tracks
//later we can implement collaborative filtering which uses user behavior and preferences
//to recommend the next track, we pass in the entire list of top songs and filter based on likes.

class Recommendations {
  Recommendations._();
  static final Recommendations instance = Recommendations._();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('recommendations');
  }

  /// Check if the user is still logged in
  bool _isUserLoggedIn() {
    return FirebaseAuth.instance.currentUser != null;
  }

  //Future: Function to get liked songs, then find patterns in the user's liked songs
  //! Recomendation algorithm goes here!
Future<void> getRec(List<String> likedOrRatedIDs) async {
  print('Generating new recommendations...');

  // Check if user is still logged in before starting
  if (!_isUserLoggedIn()) {
    print('User signed out, aborting recommendation generation');
    return;
  }

  final recTrackIds = <String, Map<String, dynamic>>{}; // trackId -> {track, sources}
  final pendingFetches = <Future<void>>[]; // Track all pending track detail fetches
  int newRecTrackLength = 0;

  try {
    //Parallelize queries for all liked tracks instead of processing sequentially
    //Map each future to its corresponding likedId for robust tracking
    final coLikedQueries = <(String likedId, Future<QuerySnapshot> query, String type)>[]; 
    
    for (final likedId in likedOrRatedIDs) {
      if (!_isUserLoggedIn()) {
        print('User signed out during recommendation generation, aborting');
        return;
      }

      print('Processing liked/rated track ID: $likedId');
      
      // Queue both queries in parallel for this track, tracking which is which
      coLikedQueries.add((
        likedId,
        FirebaseFirestore.instance
            .collection('co_liked')
            .where('songA', isEqualTo: likedId)
            .orderBy('count', descending: true)
            .limit(5)
            .get(),
        'songA'
      ));
      
      coLikedQueries.add((
        likedId,
        FirebaseFirestore.instance
            .collection('co_liked')
            .where('songB', isEqualTo: likedId)
            .orderBy('count', descending: true)
            .limit(5)
            .get(),
        'songB'
      ));
    }
    
    if (coLikedQueries.isEmpty) {
      print("No liked tracks to process, skipping recommendation generation.");
      return;
    }
    
    //map the list of futures to their corresponding liked track IDs and query types for robust processing later
    final results = await Future.wait(
      coLikedQueries.map((item) => item.$2)
    );
    
    if (!_isUserLoggedIn()) {
      print('User signed out during recommendation generation, aborting');
      return;
    }
    
    //process query results with explicit mapping to liked track IDs
    for (int i = 0; i < results.length; i++) {
      final (likedId, _, queryType) = coLikedQueries[i];
      final snapshot = results[i];
      
      if (queryType == 'songA') {
        // Extract songB from docs where songA == likedId
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final songB = data['songB'];
          //skip if already liked
          if(hasUserAlreadyLiked(likedOrRatedIDs, songB)) continue;
          if (songB != null) {
            if (!recTrackIds.containsKey(songB)) {
              recTrackIds[songB] = {
                'track': null, // Will be filled in parallel
                'sources': <String>{},
                'colikeCount': 0.0,
              };
              // Parallelize track detail fetch
              pendingFetches.add(
                fetchTrackDetails(songB).then((track) {
                  recTrackIds[songB]!['track'] = track;
                }).catchError((e) {
                  print('Error fetching track $songB: $e');
                })
              );
            }
            (recTrackIds[songB]!['sources'] as Set<String>).add(likedId);
            final cnt = (data['count'] as num?)?.toDouble() ?? 0.0;
            recTrackIds[songB]!['colikeCount'] = (recTrackIds[songB]!['colikeCount'] as double) + cnt;
            newRecTrackLength++;
          }
        }
      } else {
        // Extract songA from docs where songB == likedId
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final songA = data['songA'];
          if(hasUserAlreadyLiked(likedOrRatedIDs, songA)) continue;
          if (songA != null) {
            if (!recTrackIds.containsKey(songA)) {
              recTrackIds[songA] = {
                'track': null, // Will be filled in parallel
                'sources': <String>{},
                'colikeCount': 0.0,
              };
              // Parallelize track detail fetch
              pendingFetches.add(
                fetchTrackDetails(songA).then((track) {
                  recTrackIds[songA]!['track'] = track;
                }).catchError((e) {
                  print('Error fetching track $songA: $e');
                })
              );
            }
            (recTrackIds[songA]!['sources'] as Set<String>).add(likedId);
            final cnt = (data['count'] as num?)?.toDouble() ?? 0.0;
            recTrackIds[songA]!['colikeCount'] = (recTrackIds[songA]!['colikeCount'] as double) + cnt;
            newRecTrackLength++;
          }
        }
      }
    }
    
    //wait for all track detail fetches to complete
    await Future.wait(pendingFetches);
    
    print("Generated ${newRecTrackLength} new recommendations.");
  } catch (e) {
    print('Error fetching co-liked tracks: $e');
    rethrow; // Rethrow to see full stack trace for debugging
  }
  
  // Check if user is still logged in before scoring
  if (!_isUserLoggedIn()) {
    print('User signed out during recommendation generation, aborting');
    return;
  }

  // compute max colike count so we can normalize co-like counts to 0..1
  double maxColike = 0.0;
  for (final v in recTrackIds.values) {
    final c = (v['colikeCount'] as double?) ?? 0.0;
    if (c > maxColike) maxColike = c;
  }

  // fetch accepted friends to compute friend-based score
  final uid = _uid;
  if (uid == null) {
    print('User signed out, aborting recommendation generation');
    return;
  }

  final friendSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('friends')
      .where('status', isEqualTo: 'accepted')
      .get();

  if (!_isUserLoggedIn()) {
    print('User signed out during recommendation generation, aborting');
    return;
  }

  final friendUids = friendSnap.docs.map((d) => d.id).toList();
  
  // Fetch friend rating data in one batch instead of per-track
  final friendRatingData = await _computeFriendRatingsForAllTracks(friendUids, recTrackIds.keys.toList());

  // Batch all setRecommended calls to run in parallel
  final setRecFutures = <Future<void>>[];
  
  for (final entry in recTrackIds.entries) {
    if (!_isUserLoggedIn()) {
      print('User signed out during recommendation saving, aborting');
      return;
    }

    final track = entry.value['track'] as Track?;
    if (track == null) continue; // Skip if track details failed to load
    
    final sources = entry.value['sources'] as Set<String>;
    final colikeCount = (entry.value['colikeCount'] as double?) ?? 0.0;

    final double colikeNorm = maxColike > 0 ? (colikeCount / maxColike) : 0.0;
    
    // Get cached friend score instead of computing per-track
    final friendScore = friendRatingData[track.id] ?? 0.0;
    final popularityNorm = track.score != null ? (track.score! / 100) : 0.0;

    //! Simple weighted scoring formula - can be tuned or made more complex later
    //! 60% popularity, 20% friend score, 20% co-like score - can adjust weights as needed
    final double score = 0.6 * colikeNorm + 0.2 * friendScore + 0.2 * popularityNorm;

    //queue the write instead of awaiting immediately
    setRecFutures.add(
      setRecommended(
        trackId: track.id!,
        name: track.name,
        artists: track.artists,
        durationMs: track.durationMs,
        explicit: track.explicit,
        url: track.url,
        albumImageUrl: track.albumImageUrl,
        recommend: true,
        sourceTrackIds: sources.toList(),
        score: score,
      )
    );
  }
  
  // Wait for all writes to complete in parallel
  await Future.wait(setRecFutures);
}

  //! Firestore functions to save recommended tracks for user

   /// Toggle  flag (true/false).
  Future<void> setRecommended({
    required String trackId,
    required String name,
    required int durationMs,
    required bool explicit,
    required String url,
    required String artists,
    String? albumImageUrl,
    required bool recommend,
    required List<String> sourceTrackIds, //the tracks that led to this recommendation
    required double score,
  }) async {
    final col = _col;
    if (col == null) {
      print('Cannot save recommendation: user is not logged in');
      return;
    }
    await col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'durationMs': durationMs,
      'explicit': explicit,
      'url': url,
      'albumImageUrl': albumImageUrl,
      'recommend': recommend,
      'sourceTrackIds': sourceTrackIds,
      'score': score,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// streams recommended tracks for the current user.
  Stream<List<Map<String, dynamic>>> recommendedStream() {
    final col = _col;
    if (col == null) {
      return Stream.value([]); // Return empty stream if not logged in
    }
    return col.where('recommend', isEqualTo: true).snapshots().map(
      (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }

  //switch to a batch delete for more efficient deletion
  Future<void> removeRecommendationsFromSource(List<String> sourceIdSToDel) async {
    final col = _col;
    if (col == null) {
      print('Cannot remove recommendations: user is not logged in');
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    
    //iterate though ids marked for deletion
    for (var sourceTrackId in sourceIdSToDel) {
      final query = await col.where('sourceTrackIds', arrayContains: sourceTrackId).get();
      //iterate through tracks with a matching source id for deletion
      for (var doc in query.docs) {
        batch.delete(col.doc(doc.id));
      }
    }
    //delete all tracks at once
    await batch.commit(); 
  }

  //function called to remove a single song from recommendations based on source track id
  //Called when a user likes, then unlikes a song
  Future<void> removeOneSongFromSource(String sourceIdToDel) async {
    final col = _col;
    if (col == null) {
      print('Cannot remove recommendation: user is not logged in');
      return;
    }
    final query = await col.where('sourceTrackIds', arrayContains: sourceIdToDel).get();
    //iterate through tracks with a matching source id for deletion
    for (var doc in query.docs) {
      final sources = List<String>.from(doc['sourceTrackIds'] ?? []);
      sources.remove(sourceIdToDel);
      
      if (sources.isEmpty) {
        await col.doc(doc.id).delete(); //delete if no more sources
      } else {
        await col.doc(doc.id).update({'sourceTrackIds': sources});
      }
    }
  }

  bool hasUserAlreadyLiked(List<String> likedOrRatedIDs, String trackId) {
    return likedOrRatedIDs.contains(trackId);
  }
  
  /// Batch fetch all friend ratings for recommended tracks to avoid N+1 queries.
  /// Returns a map of trackId -> friend score (0.0 to 1.0)
  Future<Map<String, double>> _computeFriendRatingsForAllTracks(
    List<String> friendUids,
    List<String> trackIds,
  ) async {
    if (friendUids.isEmpty || trackIds.isEmpty) {
      return {};
    }
    
    final friendRatings = <String, Map<String, double>>{}; // trackId -> {friendUid -> rating}
    
    //batch fetch all friend ratings in parallel
    final ratingFutures = <Future<void>>[]; 
    
    for (final friendUid in friendUids) {
      ratingFutures.add(
        FirebaseFirestore.instance
            .collection('users')
            .doc(friendUid)
            .collection('ratings')
            .get()
            .then((snap) {
              //process all ratings for this friend
              for (final doc in snap.docs) {
                final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
                if (rating > 0) {
                  final trackId = doc.id;
                  if (!friendRatings.containsKey(trackId)) {
                    friendRatings[trackId] = {};
                  }
                  friendRatings[trackId]![friendUid] = rating;
                }
              }
            })
            .catchError((e) {
              print('Error fetching ratings for friend $friendUid: $e');
            })
      );
    }
    
    //wait for all friend rating fetches to complete
    await Future.wait(ratingFutures);
    
    // Compute normalized friend score for each track
    final result = <String, double>{};
    for (final trackId in trackIds) {
      final trackFriendsWhoRated = friendRatings[trackId]?.length ?? 0;
      result[trackId] = friendUids.isEmpty ? 0.0 : (trackFriendsWhoRated / friendUids.length);
    }
    
    return result;
  }

  //Fetch the track details from Spotify API given only the track ID
  Future<Track> fetchTrackDetails(String trackId) async {
    final track = await LocalMusicService().fetchTrackById(trackId);
    if (track == null) {
      throw Exception('Failed to find local track details for $trackId');
    }
    return track;
  }

  //Delete recommendation
  Future<void> deleteRecommendation(String trackId) async {
    final col = _col;
    if (col == null) {
      print('Cannot delete recommendation: user is not logged in');
      return;
    }
    await col.doc(trackId).delete();
  }

  

}
