// beginning development of recommendations algorithm, making file
import 'spotify.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'favorites.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


//when building a recomendation system, we will begin with content-based filtering
//which uses track attributes to recommend similar tracks
//later we can implement collaborative filtering which uses user behavior and preferences
//to recommend the next track, we pass in the entire list of top songs and filter based on likes.

class RecommendService {
  // RecommendService._();
  // static final RecommendService instance = RecommendService._();

  // String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // CollectionReference<Map<String, dynamic>> get _col =>
  //     FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(_uid)
  //         .collection('recommendations');

  List<Track>? likedTracks = [];
  // counter for number of recommendations made, making available tracks list respectively  
  int recCount = 0;
  List<Track> availableTracks = const [];
  
  // setter for available tracks towards recommendation
  void setAvailableTracks(List<Track> tracks) {
    availableTracks = tracks;
  }
  
  // callback to update liked songs in UI when recommendations are generated 
  void Function(List<Track>)? onUpdate;

  // setter for update callback
  void setUpdate(void Function(List<Track>) callback) {
    onUpdate = callback;
  }

  // helper function to pull artist names from a track
  Set<String> artistNames(Track track) {
    // establishing variables to hold artist names
    final names = <String>{};
    final artists = (track.artists as List?) ?? const[];

    // looping through artists to extract names from maps and/or strings
    for (final a in artists){
      // checking if artist is a map with a name key
      if (a is Map && a['name'] != null) {
        final s = a['name'].toString().trim().toLowerCase();
        if (s.isNotEmpty) names.add(s);
      }
      // checking if artist is a string
      else{
        final s = a.toString().trim().toLowerCase();
        if (s.isNotEmpty) names.add(s);
      }
    }
    return names; // returning set of artist names
  }

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
      if(tracksJson.isNotEmpty){
        //convert the most popular track json to Track object
        popularTrack = parseTrack(tracksJson[0]);
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
  void getRec(List<Track> likedSongs, String ?accessToken) async {
    Track popularTrack;
    Track songs;
    for (songs in likedSongs) {
      //iterate though liked songs and get audio features
      if (songs.id != null) {
         popularTrack = await getArtistPopularTrack(songs, accessToken!);
         print("Recommended Track: ${popularTrack.name} by ${popularTrack.artists}");
        await Future.delayed(const Duration(milliseconds: 100)); // small delay for safety
        print("_________________________________");
      }
      else{
        popularTrack = songs; //fallback if no id
      }
    }
    //filtering and recommendation logic can be added here
  }
  //function to add a track to liked songs and increment recommendation count
  void addToLiked(Track track, List<Track> likedSongs) {
    recCount++;
    likedSongs.add(track);
    print('Added to liked songs: ${track.name} by ${track.artists}');
  }


  //helper function to check if recommendation count has reached threshold
  //called in appstate
  void checkRecCount(String ?accessToken) {
    if (recCount >= 5 && likedTracks != null) {
      print("_________________________________");
      getRec(likedTracks!, accessToken!);
      recCount = 0; //reset count after getting recommendations
    }
  }

}