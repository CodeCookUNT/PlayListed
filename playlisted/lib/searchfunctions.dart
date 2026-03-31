// NOT IN USE / DEPRECATED

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'spotify.dart';

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

    await Future.delayed(const Duration(milliseconds: 120));
    var response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 429) {
      final retryAfterSeconds =
          int.tryParse(response.headers['retry-after'] ?? '') ?? 1;

      await Future.delayed(Duration(seconds: retryAfterSeconds));

      response = await http.get(
        uri,
        headers: {' Authorization': 'Bearer $token'},
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        "Song search failed: ${response.statusCode == 429 ? 'Too Many Requests' : response.body}",
      );
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
        durationMs: (json['duration_ms'] as num).toInt() ?? 0,
        explicit: json['explicit'],
        url: json['external_urls']['spotify'],
        albumImageUrl: json['album']?['images']?[0]?['url'],
        popularity: (json['popularity'] as num?)?.toInt(),
        releaseDate: json['album']?['release_date'],
        id: json['id'],
        artistId: json['artists'][0]['id'],
      );
    }).toList();
  }

  Future<List<Track>> searchArtistTopSongs(String artistName) async {
    final token = await _spotifyService.getAccessToken();

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
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
        explicit: json['explicit'],
        url: json['external_urls']['spotify'],
        albumImageUrl: json['album']?['images']?[0]?['url'],
        popularity: (json['popularity'] as num?)?.toInt(),
        releaseDate: json['album']?['release_date'],
        id: json['id'],
        artistId: json['artists'][0]['id'],
      );
    }).toList();
  }
}
