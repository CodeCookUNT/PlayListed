import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_music_service.dart';

class CoverArtService {
  static const _userAgent = 'PlayListed/1.0 (cover-art-resolver)';
  static const _minimumScore = 75;

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

      final coverUrl = await _findCoverUrl(
        artist: artist,
        releaseOrTrack: candidate,
      );

      if (coverUrl == null || coverUrl.isEmpty) {
        _coverCache[cacheKey] = null;
        continue;
      }

      _coverCache[cacheKey] = coverUrl;
      return coverUrl;
    }

    return null;
  }

  Future<String?> _findCoverUrl({
    required String artist,
    required String releaseOrTrack,
  }) async {
    final cleaned = _normalizeTitle(releaseOrTrack);
    final query = 'artist:"$artist" AND release:"$cleaned"';
    final uri = Uri.https('musicbrainz.org', '/ws/2/release', {
      'query': query,
      'fmt': 'json',
      'limit': '8',
    });

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;

      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final releases = (payload['releases'] as List?) ?? const [];
      if (releases.isEmpty) return null;

      final ranked = releases
          .whereType<Map<String, dynamic>>()
          .where((release) {
            final score =
                int.tryParse((release['score'] ?? '0').toString()) ?? 0;
            return score >= _minimumScore;
          })
          .toList()
        ..sort((a, b) {
          final aScore = int.tryParse((a['score'] ?? '0').toString()) ?? 0;
          final bScore = int.tryParse((b['score'] ?? '0').toString()) ?? 0;
          return bScore.compareTo(aScore);
        });

      if (ranked.isEmpty) return null;

      final best = ranked.first;
      final releaseId = (best['id'] as String?)?.trim();
      if (releaseId != null && releaseId.isNotEmpty) {
        return 'https://coverartarchive.org/release/$releaseId/front-250';
      }

      final releaseGroup = best['release-group'] as Map<String, dynamic>?;
      final releaseGroupId = (releaseGroup?['id'] as String?)?.trim();
      if (releaseGroupId != null && releaseGroupId.isNotEmpty) {
        return 'https://coverartarchive.org/release-group/$releaseGroupId/front-250';
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String _normalizeTitle(String value) {
    final normalized = value
        .replaceAll(
          RegExp(
            r'\(.*?(deluxe|expanded|remaster|edition).*?\)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\[.*?(deluxe|expanded|remaster|edition).*?\]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? value.trim() : normalized;
  }

  String _primaryArtist(String artists) {
    final first = artists.split(',').first.trim();
    return first;
  }
}
