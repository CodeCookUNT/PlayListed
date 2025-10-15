import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

//Track Class for holding track info
class Track {
  final String name;
  final String artists;
  final int durationMs;
  final bool explicit;
  final String url;

  Track({
    required this.name,
    required this.artists,
    required this.durationMs,
    required this.explicit,
    required this.url,
  });
}

//The .env won't be pushed to git you gonna need to make it :}

class SpotifyService {
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


  Future<List<Track>> fetchTopTracks(String? accessToken) async {
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/albums/4aawyAB9vmqN3uQ7FjRGTy'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      //decode the json response
      final data = jsonDecode(response.body);
      //extract the list of tracks
      final items = data['tracks']['items'] as List;
      //map each track to our Track class
      return items.map((track) {
        return Track(
          name: track['name'],
          //join each artists with a ', ' since there could be multiple artists per track
          artists: (track['artists'] as List)
              .map((a) => a['name'])
              .join(', '),
          durationMs: track['duration_ms'],
          explicit: track['explicit'],
          url: track['external_urls']['spotify'],
        );
      }).toList();
    }
    else {
      throw Exception('Failed to load top tracks');
    }
  }

}