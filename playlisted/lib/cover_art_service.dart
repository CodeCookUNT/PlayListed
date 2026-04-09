import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_music_service.dart';

class CoverArtService {
  static const _userAgent = 'PlayListed/1.0 (cover-art-resolver)';

  final Map<String, String?> _coverCache = {};

  Future<String?> resolveForTrack(Track track) async {
    final existing = track.albumImageUrl?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final artist = _primaryArtist(track.artists);
    if (artist.isEmpty) return null;

    final candidates = <String>{
      if ((track.albumName ?? '').trim().isNotEmpty) track.albumName!.trim(),
      track.name.trim(),
    };

    for (final candidate in candidates) {
      final cacheKey = '${artist.toLowerCase()}|${candidate.toLowerCase()}';
      if (_coverCache.containsKey(cacheKey)) {
        final cached = _coverCache[cacheKey];
        if (cached != null && cached.isNotEmpty) return cached;
        continue;
      }

      final mbid = await _findReleaseGroupMbid(
        artist: artist,
        releaseOrTrack: candidate,
      );

      if (mbid == null) {
        _coverCache[cacheKey] = null;
        continue;
      }

      final artUrl = 'https://coverartarchive.org/release-group/$mbid/front-250';
      final exists = await _urlLooksReachable(artUrl);

      _coverCache[cacheKey] = exists ? artUrl : null;
      if (exists) return artUrl;
    }

    return null;
  }

  Future<String?> _findReleaseGroupMbid({
    required String artist,
    required String releaseOrTrack,
  }) async {
    final query = 'artist:"$artist" AND release:"$releaseOrTrack"';
    final uri = Uri.https('musicbrainz.org', '/ws/2/release-group', {
      'query': query,
      'fmt': 'json',
      'limit': '5',
    });

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;

      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final releaseGroups = (payload['release-groups'] as List?) ?? const [];
      if (releaseGroups.isEmpty) return null;

      releaseGroups.sort((a, b) {
        final aScore = int.tryParse((a['score'] ?? '0').toString()) ?? 0;
        final bScore = int.tryParse((b['score'] ?? '0').toString()) ?? 0;
        return bScore.compareTo(aScore);
      });

      final best = releaseGroups.first as Map<String, dynamic>;
      return best['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _urlLooksReachable(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _primaryArtist(String artists) {
    final first = artists.split(',').first.trim();
    return first;
  }
}
