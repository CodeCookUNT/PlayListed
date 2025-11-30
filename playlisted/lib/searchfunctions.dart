import 'dart:convert';
import 'package:http/http.dart' as http;
import 'spotify.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SearchFunctions {
  final SpotifyService _spotifyService = SpotifyService();

  // 1. Search for individual songs by name
  Future<List<Track>> searchSongs(String query) async {
    final token = await _spotifyService.getAccessToken();

    final uri = Uri.https(
      'api.spotify.com',
      '/v1/search',
      {
        'q': query,
        'type': 'track',
        'limit': '20',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception("Song search failed: ${response.body}");
    }

    final data = jsonDecode(response.body);
    final tracks = data['tracks']['items'] as List;

    return tracks.map((json) {
      final artists = (json['artists'] as List)
          .map((artist) => artist['name'])
          .join(', ');

      return Track(
        name: json['name'],
        artists: artists,
        durationMs: json['duration_ms'],
        explicit: json['explicit'],
        url: json['external_urls']['spotify'],
        albumImageUrl: json['album']?['images']?[0]?['url'],
        popularity: json['popularity'],
        releaseDate: json['album']?['release_date'],
        id: json['id'],
        artistId: json['artists'][0]['id'],
      );
    }).toList();
  }

  // 2. Search artist → return their top tracks
  Future<List<Track>> searchArtistTopSongs(String artistName) async {
    final token = await _spotifyService.getAccessToken();

    // Step 1: search artist to get ID
    final artistUri = Uri.https(
      'api.spotify.com',
      '/v1/search',
      {
        'q': artistName,
        'type': 'artist',
        'limit': '1',
      },
    );

    final artistResponse = await http.get(
      artistUri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (artistResponse.statusCode != 200) {
      throw Exception("Artist search failed: ${artistResponse.body}");
    }

    final artistData = jsonDecode(artistResponse.body);
    final artistItems = artistData['artists']['items'];

    if (artistItems.isEmpty) return [];

    final artistId = artistItems[0]['id'];

    // Step 2: fetch top tracks
    final topTracksUri = Uri.https(
      'api.spotify.com',
      '/v1/artists/$artistId/top-tracks',
      {'market': 'US'},
    );

    final topTracksResponse = await http.get(
      topTracksUri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (topTracksResponse.statusCode != 200) {
      throw Exception("Top song fetch failed: ${topTracksResponse.body}");
    }

    final topData = jsonDecode(topTracksResponse.body);
    final trackList = topData['tracks'] as List;

    return trackList.map((json) {
      final artists = (json['artists'] as List)
          .map((artist) => artist['name'])
          .join(', ');

      return Track(
        name: json['name'],
        artists: artists,
        durationMs: json['duration_ms'],
        explicit: json['explicit'],
        url: json['external_urls']['spotify'],
        albumImageUrl: json['album']?['images']?[0]?['url'],
        popularity: json['popularity'],
        releaseDate: json['album']?['release_date'],
        id: json['id'],
        artistId: json['artists'][0]['id'],
      );
    }).toList();
  }
}
