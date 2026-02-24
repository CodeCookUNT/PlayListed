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
          .limit(2)
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
            };
          }
          (recTrackIds[songB]!['sources'] as Set<String>).add(likedId);
        }
      }

      //songB == likedId
      final q2 = await FirebaseFirestore.instance
          .collection('co_liked')
          .where('songB', isEqualTo: likedId)
          .orderBy('count', descending: true)
          .limit(2)
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
            };
          }
          (recTrackIds[songA]!['sources'] as Set<String>).add(likedId);
        }
      }
    }
    print("Generated ${recTrackIds.length} new recommendations.");
  } catch (e) {
    print('Error fetching co-liked tracks: $e');
  }
  
  for (final entry in recTrackIds.entries) {
    final track = entry.value['track'] as Track;
    final sources = entry.value['sources'] as Set<String>;
    
    await setRecommended(
      trackId: track.id!,
      name: track.name,
      artists: track.artists,
      albumImageUrl: track.albumImageUrl,
      recommend: true,
      sourceTrackIds: sources.toList(),
      score: track.popularityScore ?? 0,
    );
  }
}

  //! Firestore functions to save recommended tracks for user

   /// Toggle  flag (true/false).
  Future<void> setRecommended({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    required bool recommend,
    required List<String> sourceTrackIds, //the tracks that led to this recommendation
    required int score,
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
      popularityScore: (json['popularity'] + 10.0 > 100) ? 100 : json['popularity'] + 10.0, //inc score by 10, cap to 100
    );
  }

  

}
