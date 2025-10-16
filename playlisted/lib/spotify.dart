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

//! The .env won't be pushed to git you gonna need to make it :}
//! To make the the file first, you need to make the .env(wirte as this) in same space as the pubspecs file. 
//! Then in the .env file put SPOTIFY_CLIENT_ID=placeholder and SPOTIFY_CLIENT_SECRET=placeholder
//! Replace the placeholder with actully numbers from the spotify devloper app or the number on I put in discord   

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
      final tracksJson = data['tracks']['items'] as List;
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
    }
    else {
      throw Exception('Failed to load top tracks');
    }
  }

}