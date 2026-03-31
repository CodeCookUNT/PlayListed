// NOT IN USE / DEPRECATED

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

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
      final spotifyRecs = await getRandomPopSongs(limit: 8); 
      for (final track in spotifyRecs) {
        if (feed.length >= 8) break;
        _addUnique(track);
      }
      print('fetchSongs: Now have ${feed.length} recommendations');
    }

    // 2. Add 3 popular songs
    print('fetchSongs: Fetching popular tracks...');
    final popular =  await getRandomPopSongs(limit: 3); 
    int addedPopular = 0;
    for (final track in popular) {
      if (addedPopular >= 3) break;
      final oldLen = feed.length;
      _addUnique(track);
      if (feed.length > oldLen) addedPopular++;
    }
    print('fetchSongs: Added $addedPopular popular tracks, total now ${feed.length}');


    // 4. Ensure we hit the exact limit
    if (feed.length < limit) {
      print('fetchSongs: Under limit (${feed.length} < $limit), fetching ${limit - feed.length} extra...');
      final extra = await getRandomPopSongs(limit: limit - feed.length);
      for (final track in extra) {
        if (feed.length >= limit) break;
        _addUnique(track);
      }
      print('fetchSongs: Total now ${feed.length}');

      // final fallback: if we still didn't reach the limit because every
      // candidate was already seen, allow a duplicate rather than returning an empty list
      if (feed.isEmpty) {
        final fallback = await getRandomPopSongs(limit: limit);
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
  

  Future<List<Track>> getRandomPopSongs({int limit = 10}) async {
    List<Track> feed = [];
    //open file
    final popFile = File('lib/Data/high_popularity_spotify_data.csv');
    final lines = await popFile.readAsLines();

    //randomly select x Lines
    final selectedLines = lines.skip(1).toList()..shuffle()..take(limit);

    for(var line in selectedLines){ //skip header
      feed.add(parseLine(line));
    }
    return feed;
  }

  Track parseLine(String line) {
    final columns = line.split(',');
    if (columns.length < 5) return Track(name: '', artists: '', durationMs: 0, explicit: false, url: '');
    final name = columns[0].trim();
    final artists = columns[1].trim();
    final durationMs = int.tryParse(columns[2].trim()) ?? 0;
    final explicit = (columns.length > 3 && columns[3].trim().toLowerCase() == 'true');
    final url = columns.length > 4 ? columns[4].trim() : '';
    final albumImageUrl = columns.length > 5 ? columns[5].trim() : null;
    final popularity = columns.length > 6 ? int.tryParse(columns[6].trim()) : null;
    final releaseDate = columns.length > 7 ? columns[7].trim() : null;
    final id = columns.length > 8 ? columns[8].trim() : null;
    return Track(
      name: name,
      artists: artists,
      durationMs: durationMs,
      explicit: explicit,
      url: url,
      albumImageUrl: albumImageUrl?.isEmpty == true ? null : albumImageUrl,
      popularity: popularity,
      releaseDate: releaseDate?.isEmpty == true ? null : releaseDate,
      id: id?.isEmpty == true ? null : id,
      score: popularity != null ? (popularity / 100.0) : null,
    );
  }


  
  Future<List<Track>> fetchTopSongs(String? accessToken, {String? yearRange, int limit = 500}) async {
    return [];
  }

  Future<Map<Track, double>> fetchRecommendedSongs() async{
    if (FirebaseAuth.instance.currentUser == null) {
      print("fetchRecommendedSongs: User not authenticated");
      return {};
    }

    print("fetchRecommendedSongs: Starting fetch for user $_uid");

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
        final track = Track(
          name: doc['name'] ?? '',
          artists: doc['artists'] ?? '',
          durationMs: doc['durationMs'] ?? 0,
          explicit: doc['explicit'] ?? false,
          url: doc['url'] ?? '',
          albumImageUrl: doc['albumImageUrl'],
          score: doc['score'] != null ? (doc['score'] as num).toDouble() : 0.0,
          id: doc.id,
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
