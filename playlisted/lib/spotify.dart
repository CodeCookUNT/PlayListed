import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recommendations.dart';

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
  final int? popularityScore;

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
    this.popularityScore,
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

  Future<List<Track>> fetchTopSongs(String? accessToken, {String? yearRange, int limit = 500}) async {
    List<Track> allTracks = [];
    
    // If yearRange is provided, search specifically for that decade
    if (yearRange != null) {
      final searchQueries = [
        'year:$yearRange',
        'year:$yearRange genre:pop',
        'year:$yearRange genre:rock',
        'year:$yearRange genre:hip-hop',
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
          continue;
        }
      }
    } else {
      // Original behavior - search across multiple genres
      final searchQueries = [
        'year:1970-1979',
        'genre:pop',
        'genre:rock',
        'genre:hip-hop',
        'genre:r&b',
        'genre:country',
        'genre:electronic',
        'genre:indie',
      ];
      
      for (String query in searchQueries) {
        try {
          final tracks = await _searchTracks(accessToken, query, limit: 50);
          allTracks.addAll(tracks);
          
          // Stop if we've reached ~500 songs
          if (allTracks.length >= 500) {
            break;
          }
        } catch (e) {
          print('Error searching for $query: $e');
          continue;
        }
      }
    }
    
    // Remove duplicates based on track name and artist
    final uniqueTracks = <String, Track>{};
    for (var track in allTracks) {
      final key = '${track.name}-${track.artists}';
      uniqueTracks[key] = track;
      print("${track.name} by ${track.artists} SCORE: ${track.popularityScore}");
    }
    

    // Shuffle to mix songs from different searches
    final shuffledTracks = uniqueTracks.values.toList()..shuffle();
    
    // Return up to the limit
    return shuffledTracks.take(limit).toList();
  }

  // Helper method to search for tracks
  Future<List<Track>> _searchTracks(String? accessToken, String query, {int limit = 50}) async {
    final uri = Uri.https(
      'api.spotify.com',
      '/v1/search',
      {
        'q': query,
        'type': 'track',
        'limit': limit.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

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
        );
      }).toList();
    } else {
      throw Exception('Failed to search tracks: ${response.body}');
    }
  }

Future<List<Track>> sortRecommendedTracks(List<Track> recommendedSongs) async{
  // Sort the loaded songs by popularity score in descending order
  final sortedSongs = recommendedSongs.toList()
    ..sort((a, b) => b.popularityScore!.compareTo(a.popularityScore!));

  return sortedSongs;
}

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tracksJson = data['tracks'] as List;
      return tracksJson.map((json) {
        final artists = (json['artists'] as List)
            .map((artist) => artist['name'])
            .join(', ');
        return Track(
          name: json['name'],
          artists: artists,
          durationMs: json['duration_ms'],
          explicit: json['explicit'],
          url: json['external_urls']['spotify'],
        );
      }).toList();
    } else {
      throw Exception('Failed to fetch recommendations: ${response.body}');
    }
  }
}