// beginning development of recommendations algorithm, making file
import 'spotify.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';



//when building a recomendation system, we will begin with content-based filtering
//which uses track attributes to recommend similar tracks
//later we can implement collaborative filtering which uses user behavior and preferences
//to recommend the next track, we pass in the entire list of top songs and filter based on likes.

class Recommendations {
  Recommendations._();
  static final Recommendations instance = Recommendations._();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('recommendations');

  //Future: Function to get liked songs, then find patterns in the user's liked songs
  //! Recomendation algorithm goes here!
Future<void> getRec(List<String> likedOrRatedIDs, String? accessToken) async {
  print('Generating new recommendations...');

  final recTrackIds = <String, Map<String, dynamic>>{}; // trackId -> {track, sources}

  try {
    //for each liked or rated track, find co-liked tracks
    for (final likedId in likedOrRatedIDs) {

      //2 CASES: songA is the likedId or songB is the likedId
      //Cannot query songA OR songB in a single query, so we do two separate queries
      
      //songA == likedId
      final q1 = await FirebaseFirestore.instance
          .collection('co_liked')
          .where('songA', isEqualTo: likedId)
          .orderBy('count', descending: true)
          .limit(8)
          .get();

      //extract songB from each document
      for (final doc in q1.docs) {
        final data = doc.data();
        final songB = data['songB'];
        if(hasUserAlreadyLiked(likedOrRatedIDs, songB)){
          continue; //skip if user has already liked/rated this track
        }
        if (songB != null) {
          final track = await fetchTrackDetails(songB, accessToken);
          if (!recTrackIds.containsKey(songB)) {
            recTrackIds[songB] = {
              'track': track,
              'sources': <String>{},
              'colikeCount': 0.0,
            };
          }
          (recTrackIds[songB]!['sources'] as Set<String>).add(likedId);
          //track the colike count to compute score later
          final cnt = (data['count'] as num?)?.toDouble() ?? 0.0;
          recTrackIds[songB]!['colikeCount'] = (recTrackIds[songB]!['colikeCount'] as double) + cnt;
        }
      }

      //songB == likedId
      final q2 = await FirebaseFirestore.instance
          .collection('co_liked')
          .where('songB', isEqualTo: likedId)
          .orderBy('count', descending: true)
          .limit(8)
          .get();

      //extract songA from each document
      for (final doc in q2.docs) {
        final data = doc.data();
        final songA = data['songA'];
        if(hasUserAlreadyLiked(likedOrRatedIDs, songA)){
          continue; //skip if user has already liked/rated this track
        }
        if (songA != null) {
          final track = await fetchTrackDetails(songA, accessToken);
          if (!recTrackIds.containsKey(songA)) {
            recTrackIds[songA] = {
              'track': track,
              'sources': <String>{},
              'colikeCount': 0.0,
            };
          }
          (recTrackIds[songA]!['sources'] as Set<String>).add(likedId);
          //track the colike count to compute score later
          final cnt = (data['count'] as num?)?.toDouble() ?? 0.0;
          recTrackIds[songA]!['colikeCount'] = (recTrackIds[songA]!['colikeCount'] as double) + cnt;
        }
      }
    }
    print("Generated ${recTrackIds.length} new recommendations.");
  } catch (e) {
    print('Error fetching co-liked tracks: $e');
  }
  
  // compute max colike count so we can normalize co-like counts to 0..1
  double maxColike = 0.0;
  for (final v in recTrackIds.values) {
    final c = (v['colikeCount'] as double?) ?? 0.0;
    if (c > maxColike) maxColike = c;
  }

  // fetch accepted friends to compute friend-based score
  final friendSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('friends')
      .where('status', isEqualTo: 'accepted')
      .get();
  final friendUids = friendSnap.docs.map((d) => d.id).toList();

  for (final entry in recTrackIds.entries) {
    final track = entry.value['track'] as Track;
    final sources = entry.value['sources'] as Set<String>;
    final colikeCount = (entry.value['colikeCount'] as double?) ?? 0.0;

    //normalize co-like count
    final double colikeNorm = maxColike > 0 ? (colikeCount / maxColike) : 0.0;

    //compute friend score: fraction of accepted friends who have rated/liked this track
    int friendLikes = 0;
    for (final f in friendUids) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(f)
            .collection('ratings')
            .doc(track.id)
            .get();
        if (doc.exists) {
          final rating = (doc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
          if (rating > 0) friendLikes++;
        }
      } catch (e) {
        //ignore per-friend lookup errors
      }
    }
    final friendScore = friendUids.isEmpty ? 0.0 : (friendLikes / friendUids.length);

    final popularityNorm = track.popularityScore != null ? (track.popularityScore! / 100) : 0.0;

    //final weighted score: 0.6 * colike + 0.2 * friend + 0.2 * popularity
    final double score = 0.6 * colikeNorm + 0.2 * friendScore + 0.2 * popularityNorm;

    await setRecommended(
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
    );
  }
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
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'recommend': recommend,
      'sourceTrackIds': sourceTrackIds,
      'score': score,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// streams recommended tracks for the current user.
  Stream<List<Map<String, dynamic>>> recommendedStream() {
    return _col.where('recommend', isEqualTo: true).snapshots().map(
      (snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }

  //switch to a batch delete for more efficient deletion
  Future<void> removeRecommendationsFromSource(List<String> sourceIdSToDel) async {
    final batch = FirebaseFirestore.instance.batch();
    
    //iterate though ids marked for deletion
    for (var sourceTrackId in sourceIdSToDel) {
      final query = await _col.where('sourceTrackIds', arrayContains: sourceTrackId).get();
      //iterate through tracks with a matching source id for deletion
      for (var doc in query.docs) {
        batch.delete(_col.doc(doc.id));
      }
    }
    //delete all tracks at once
    await batch.commit(); 
  }

  //function called to remove a single song from recommendations based on source track id
  //Called when a user likes, then unlikes a song
  Future<void> removeOneSongFromSource(String sourceIdToDel) async {
    final query = await _col.where('sourceTrackIds', arrayContains: sourceIdToDel).get();
    //iterate through tracks with a matching source id for deletion
    for (var doc in query.docs) {
      final sources = List<String>.from(doc['sourceTrackIds'] ?? []);
      sources.remove(sourceIdToDel);
      
      if (sources.isEmpty) {
        await _col.doc(doc.id).delete(); //delete if no more sources
      } else {
        await _col.doc(doc.id).update({'sourceTrackIds': sources});
      }
    }
  }

  bool hasUserAlreadyLiked(List<String> likedOrRatedIDs, String trackId) {
    return likedOrRatedIDs.contains(trackId);
  }

  //Fetch the track details from Spotify API given only the track ID
  Future<Track> fetchTrackDetails(String trackId, String? accessToken) async {
    //get the track details from Spotify API
    final uri = Uri.https(
      'api.spotify.com',
      '/v1/tracks/$trackId',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if(response.statusCode != 200){
      throw Exception('Failed to fetch track details: ${response.body}');
    }
    final json = jsonDecode(response.body);
    final artists = (json['artists'] as List)
        .map((artist) => artist['name'])
        .join(', ');
    String? albumImageUrl;
    if (json['album'] != null &&
        json['album']['images'] != null &&
        (json['album']['images'] as List).isNotEmpty) {
      albumImageUrl = json['album']['images'][0]['url'];
    }
    //return Track object
    return Track(
      name: json['name'],
      artists: artists,
      durationMs: json['duration_ms'],
      explicit: json['explicit'],
      url: json['external_urls']['spotify'],
      albumImageUrl: albumImageUrl,
      popularity: json['popularity'],
      releaseDate: json['album'] != null ? json['album']['release_date'] : null,
      id: json['id'],
      artistId: (json['artists'] != null && (json['artists'] as List).isNotEmpty)
          ? json['artists'][0]['id']
          : null,
      popularityScore: json['popularity'] != null ? (json['popularity']) : 0,
    );
  }

  

}
