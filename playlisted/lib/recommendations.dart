// beginning development of recommendations algorithm, making file
import 'package:flutter/material.dart';
import 'spotify.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'colike.dart';
import 'main.dart' show MyAppState;



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


  //helper function to parse track json data into Track object
  Track parseTrack(var data){
    final artists = (data['artists'] as List)
        .map((artist) => artist['name'])
        .join(', ');

    //get album image URL from the track's album
    String? albumImageUrl;
    if (data['album'] != null && data['album']['images'] != null) {
      final images = data['album']['images'] as List;
      if (images.isNotEmpty) {
        albumImageUrl = images.length > 1 ? images[1]['url'] : images[0]['url'];
      }
    }
    return Track(
      name: data['name'],
      artists: artists,
      durationMs: data['duration_ms'],
      albumImageUrl: albumImageUrl,
      popularity: data['popularity'],
      url: data['external_urls']['spotify'],
      explicit: data['explicit'],
      releaseDate: data['album'] != null ? data['album']['release_date'] : null,
      id: data['id'],
      artistId: (data['artists'] != null && (data['artists'] as List).isNotEmpty)
          ? data['artists'][0]['id']
          : null,
    );
  }

  //helper function to get a tracks stats
  Future<Track> getArtistPopularTrack(Track track, String? accessToken) async {
    final Track popularTrack;
    final uri = Uri.https(
      'api.spotify.com',
      '/v1/artists/${track.artistId}/top-tracks',
      {'market': 'US'},
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if(response.statusCode == 200){
      final data = jsonDecode(response.body);
      final tracksJson = data['tracks'] as List;
      if(tracksJson.isNotEmpty && tracksJson[0]['id'] != track.id){
        //convert the most popular track json to Track object
        popularTrack = parseTrack(tracksJson[0]);
      }
      else if(tracksJson.length > 1){
        //if the most popular track is the same as the original, take the next popular
        popularTrack = parseTrack(tracksJson[1]);
      }
      else{
        popularTrack = track; //fallback to the original track if no top tracks found
      }
      return popularTrack;
    }
    else{
      throw Exception('Failed to get artist top tracks: ${response.body}');
    }

  }

  //Future: Function to get liked songs, then find patterns in the user's liked songs
  //! Recomendation algorithm goes here!
Future<void> getRec(List<String> likedOrRatedIDs) async {
  final recTrackIds = <String>{};

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
          .limit(3)
          .get();

      //extract songB from each document
      for (final doc in q1.docs) {
        final data = doc.data();
        final songB = data['songB'];
        if (songB != null) {
          recTrackIds.add(songB);
        }
      }

      //songB == likedId
      final q2 = await FirebaseFirestore.instance
          .collection('co_liked')
          .where('songB', isEqualTo: likedId)
          .orderBy('count', descending: true)
          .limit(3)
          .get();

      //extract songA from each document
      for (final doc in q2.docs) {
        final data = doc.data();
        final songA = data['songA'];
        if (songA != null) {
          recTrackIds.add(songA);
        }
      }
    }
  } catch (e) {
    print('Error fetching co-liked tracks: $e');
  }

  print('Recommended Track IDs: $recTrackIds');
}

  //! Firestore functions to save recommended tracks for user

   /// Toggle  flag (true/false).
  Future<void> setRecommended({
    required String trackId,
    required String name,
    required String artists,
    String? albumImageUrl,
    required bool recommend,
    required String sourceTrackId, //the track that led to this recommendation
  }) async {
    await _col.doc(trackId).set({
      'name': name,
      'artists': artists,
      'albumImageUrl': albumImageUrl,
      'recommend': recommend,
      'sourceTrackId': sourceTrackId,
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
      final query = await _col.where('sourceTrackId', isEqualTo: sourceTrackId).get();
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
    final query = await _col.where('sourceTrackId', isEqualTo: sourceIdToDel).get();
      //iterate through tracks with a matching source id for deletion
      for (var doc in query.docs) {
        await _col.doc(doc.id).delete();
      }
  }

  // Future<void> recDeleteTrack({required String trackId}) async {
  //   await _col.doc(trackId).delete();
  // }


  void addRecTrackToList(Track recTrack, List<Track>? tracks, int currIndex){
    //get the appstates list and insert a recommended track
    tracks?.insert(currIndex+5, recTrack);
  }

}
