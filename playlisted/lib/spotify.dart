import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//Track Class for holding track info
class Track {
  final String name;
  final String artists;
  final int durationMs;
  final bool explicit;
  final String url;
  final String? albumImageUrl;
  final int? popularity;
  final String? releaseDate;
  final String? id;
  final String? artistId;
  final double? score;

  Track({
    required this.name,
    required this.artists,
    required this.durationMs,
    required this.explicit,
    required this.url,
    this.albumImageUrl,
    this.popularity,
    this.releaseDate,
    this.id,
    this.artistId,
    this.score,
  });
}

//! The .env won't be pushed to git you gonna need to make it :}
//! To make the the file first, you need to make the .env(write as this) in same space as the pubspecs file. 
//! Then in the .env file put SPOTIFY_CLIENT_ID=placeholder and SPOTIFY_CLIENT_SECRET=placeholder
//! Replace the placeholder with actully numbers from the spotify devloper app or the number on I put in discord   

class SpotifyService {

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<String> getAccessToken() async {
    final clientId = dotenv.env['SPOTIFY_CLIENT_ID']!;
    final clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET']!;

    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
    
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'), //Endpoint to get the access token
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Failed to get token: ${response.body}');
    }
  }

  //fetch 8 rec songs, 3 popular songs, and 1 random popular song, ensures the same track is not seen twice
  Future<List<Track>> fetchSongs(String accessToken, Map<Track, double> recTracks, {String? yearRange, int limit = 10, Set<String>? excludeIds, Set<String>? excludeNameArtist}) async{
    print('fetchSongs: Starting with ${recTracks.length} recommendation tracks, limit=$limit');
    
    // Track seen songs by ID and name+artist to avoid duplicates
    final seenIds = <String>{...(excludeIds ?? {})}; // include pre-existing exclusions
    final seenNameArtist = <String>{...(excludeNameArtist ?? {})};
    final feed = <Track>[];

    void _addUnique(Track track) {
      final key = '${track.name}|${track.artists}'.toLowerCase();
      
      //check by ID first if available
      if (track.id != null && track.id!.isNotEmpty) {
        if (seenIds.contains(track.id)) {
          print('  skipping duplicate (by ID): ${track.name}');
          return;
        }
        seenIds.add(track.id!);
      }
      
      //also check by name+artist
      if (seenNameArtist.contains(key)) {
        print('  skipping duplicate (by name): ${track.name}');
        return;
      }
      seenNameArtist.add(key);
      
      feed.add(track);
    }

    //ignore any recommendation entries that lack an ID; without it we
    //can't show ratings/reviews and they could later trigger null
    //assertion errors when we try to reference `.id`.
    final validRec = recTracks.entries
        .where((e) => e.key.id != null && e.key.id!.isNotEmpty)
        .toList();
    
    print('fetchSongs: ${validRec.length} valid recommendations available');

    // 1. Collect 8 unique recommended tracks
    //    Start with the highest-scoring ones, but fetch more from Spotify if skipped
    final sortedRecs = validRec..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedRecs) {
      if (feed.length >= 8) break;
      _addUnique(entry.key);
    }
    
    // If we don't have 8 recommendations yet, fetch more from Spotify API
    if (feed.length < 8) {
      print('fetchSongs: Only ${feed.length} recommendations (some were seen), fetching from Spotify API...');
      final neededCount = 8 - feed.length;
      final spotifyRecs = await fetchTopSongs(accessToken, yearRange: yearRange, limit: neededCount * 2);
      for (final track in spotifyRecs) {
        if (feed.length >= 8) break;
        _addUnique(track);
      }
      print('fetchSongs: Now have ${feed.length} recommendations');
    }

    // 2. Add 3 popular songs
    print('fetchSongs: Fetching popular tracks...');
    final popular = await fetchTopSongs(accessToken, yearRange: yearRange, limit: 10);
    int addedPopular = 0;
    for (final track in popular) {
      if (addedPopular >= 3) break;
      final oldLen = feed.length;
      _addUnique(track);
      if (feed.length > oldLen) addedPopular++;
    }
    print('fetchSongs: Added $addedPopular popular tracks, total now ${feed.length}');

    // 3. Add 1 random track for variety
    print('fetchSongs: Fetching random tracks...');
    final randomTracks = List<Track>.from(popular);
    if (randomTracks.isEmpty) {
      randomTracks.addAll(await fetchTopSongs(accessToken, yearRange: yearRange, limit: 10));
    }
    randomTracks.shuffle();
    for (final track in randomTracks) {
      final oldLen = feed.length;
      _addUnique(track);
      if (feed.length > oldLen) {
        print('fetchSongs: Added 1 random track, total now ${feed.length}');
        break;
      }
    }

    // 4. Ensure we hit the exact limit
    if (feed.length < limit) {
      print('fetchSongs: Under limit (${feed.length} < $limit), fetching ${limit - feed.length} extra...');
      final extra = await fetchTopSongs(accessToken, yearRange: yearRange, limit: limit * 3);
      for (final track in extra) {
        if (feed.length >= limit) break;
        _addUnique(track);
      }
      print('fetchSongs: Total now ${feed.length}');

      // final fallback: if we still didn't reach the limit because every
      // candidate was already seen, allow a duplicate rather than returning an empty list
      if (feed.isEmpty) {
        final fallback = await fetchTopSongs(accessToken, yearRange: yearRange, limit: limit);
        feed.addAll(fallback.take(limit));
      }
    }

    if (feed.length > limit) {
      print('fetchSongs: Over limit (${feed.length} > $limit), trimming to $limit...');
      feed.removeRange(limit, feed.length);
    }

    feed.shuffle();
    print('fetchSongs: Returning ${feed.length} unique tracks (${feed.take(8).where((t) => validRec.any((r) => r.key.id == t.id)).length} recommendations)');
    return feed;
  }
  


  
  Future<List<Track>> fetchTopSongs(String? accessToken, {String? yearRange, int limit = 500}) async {
    List<Track> allTracks = [];
    
    // If yearRange is provided, search specifically for that decade
    if (yearRange != null) {
      final searchQueries = [
        'year:$yearRange',
        'year:$yearRange genre:pop',
        // 'year:$yearRange genre:rock',
        // 'year:$yearRange genre:hip-hop',
      ];
      
      for (String query in searchQueries) {
        try {
          final tracks = await _searchTracks(accessToken, query, limit: 50);
          allTracks.addAll(tracks);
          
          // Stop if we've reached desired limit
          if (allTracks.length >= limit) {
            break;
          }
        } catch (e) {
          print('Error searching for $query: $e');
          if (e.toString().contains('Too many requests')) {
            break;
          }
          continue;
        }
      }
    } else {
      // Original behavior - search across multiple genres
      final searchQueries = [
        // 'year:1970-1979',
        'year:2010-2019',
        'genre:pop',
        'genre:rock',
        'genre:hip-hop',
        // 'genre:r&b',
        // 'genre:country',
        // 'genre:electronic',
        // 'genre:indie',
      ];
      
      for (String query in searchQueries) {
        try {
          final tracks = await _searchTracks(accessToken, query, limit: 20);
          allTracks.addAll(tracks);
          
          // Stop if we've reached ~500 songs
          if (allTracks.length >= limit) {
            break;
          }
        } catch (e) {
          print('Error searching for $query: $e');
          if (e.toString().contains('Too many requests')) {
            break;
          }
          continue;
        }
      }
    }
    
    // Remove duplicates based on track name and artist
    final uniqueTracks = <String, Track>{};
    for (var track in allTracks) {
      final key = '${track.name}-${track.artists}';
      uniqueTracks[key] = track;
    }
    

    // Shuffle to mix songs from different searches
    final shuffledTracks = uniqueTracks.values.toList()..shuffle();
    
    // Return up to the limit
    return shuffledTracks.take(limit).toList();
  }

  // Future<List<Track>> fetchSongs(Map <Track, double> trackScores){

  // }

  // Helper method to search for tracks
  Future<List<Track>> _searchTracks(String? accessToken, String query, {int limit = 50}) async {

    final safeLimit = limit.clamp(1, 50).toInt();

    Uri buildUri({int? requestLimit}) => Uri.https(
      'api.spotify.com',
      '/v1/search',
      {
        'q': query,
        'type': 'track',
        if (requestLimit != null) 'limit': requestLimit.toString(),
      },
    );

    final headers = {'Authorization': 'Bearer $accessToken'};

    Future<http.Response> doGet(Uri uri) async {
      var res = await http.get(uri, headers: headers);
      if (res.statusCode == 429) {
        final retryAfterSeconds = int.tryParse(res.headers['retry-after'] ?? '') ?? 1;
        await Future.delayed(Duration(seconds: retryAfterSeconds));
        res = await http.get(uri, headers: headers);
      }
      return res;
    }

    var response = await doGet(buildUri(requestLimit: safeLimit));

    if (response.statusCode == 400 && response.body.contains('Invalid limit')) {
      response = await doGet(buildUri(requestLimit: 20));
      if (response.statusCode == 400 && response.body.contains('Invalid limit')) {
        response = await doGet(buildUri());
      }
    }

    if (response.statusCode == 429) {
      throw Exception('Failed to search tracks: Too many requests');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tracksJson = data['tracks']['items'] as List;
      return tracksJson.map((json) {
        final artists = (json['artists'] as List)
            .map((artist) => artist['name'])
            .join(', ');
        
        // Get album image URL from the track's album
        String? albumImageUrl;
        if (json['album'] != null && json['album']['images'] != null) {
          final images = json['album']['images'] as List;
          if (images.isNotEmpty) {
            albumImageUrl = images.length > 1 ? images[1]['url'] : images[0]['url'];
          }
        }

        return Track(
          name: json['name'],
          artists: artists,
          durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
          explicit: json['explicit'],
          url: json['external_urls']['spotify'],
          albumImageUrl: albumImageUrl,
          popularity: (json['popularity'] as num?)?.toInt(),
          score: ((json['popularity'] as num?)?.toDouble() ?? 0.0) / 100,
          releaseDate: json['album'] != null ? json['album']['release_date'] : null,
          id: json['id'],
          artistId: (json['artists'] != null && (json['artists'] as List).isNotEmpty)
              ? json['artists'][0]['id']
              : null,
        );
      }).toList();
    } else {
      throw Exception('Failed to search tracks: ${response.body}');
    }
  }

  Future<Map<Track, double>> fetchRecommendedSongs() async{
    // Check if user is authenticated
  if (FirebaseAuth.instance.currentUser == null) {
    print("fetchRecommendedSongs: User not authenticated");
    return {};
  }

    print("fetchRecommendedSongs: Starting fetch for user $_uid");

    //fetch the recommended songs for the current user from firestore
    Map<Track, double> recommendedTracks = {};

    try {
      final q1 = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('recommendations')
          .get();
    
    print("fetchRecommendedSongs: Query returned ${q1.docs.length} documents");
    
    if(q1.docs.isEmpty){
        print("fetchRecommendedSongs: No recommendations found for user $_uid");
        return {};
      }

      for(var doc in q1.docs){
        // doc.id holds the Spotify track ID, so use it when constructing the
      // Track object.  This ensures later UI code can look up reviews/global
      // ratings by id.
      final track = Track(
          name: doc['name'] ?? '',
          artists: doc['artists'] ?? '',
          durationMs: doc['durationMs'] ?? 0,
          explicit: doc['explicit'] ?? false,
          url: doc['url'] ?? '',
          albumImageUrl: doc['albumImageUrl'],
          score: doc['score'] != null ? (doc['score'] as num).toDouble() : 0.0,
          id: doc.id,                       // ← important fix
        );
      final score = (doc['score'] as num?)?.toDouble() ?? 0.0;
      recommendedTracks[track] = score;
      }

      print("fetchRecommendedSongs: Fetched ${recommendedTracks.length} recommended tracks for user $_uid");
    } catch (e) {
      print("Error fetching recommendations for user $_uid: $e");
    }
    return recommendedTracks;
  }

}

