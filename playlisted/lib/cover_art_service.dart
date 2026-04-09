import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_music_service.dart';

class CoverArtService {
  static const _userAgent = 'PlayListed/1.0 (cover-art-resolver)';
  static const _minimumScore = 60;
  static const _metricsPrintEvery = 25;
  static const _hitCacheTtl = Duration(days: 7);
  static const _missCacheTtl = Duration(hours: 6);

  final Map<String, _CacheEntry> _coverCache = {};
  int _lookupAttempts = 0;
  int _lookupHits = 0;
  int _lookupMisses = 0;

  Future<String?> resolveForTrack(Track track) async {
    final existing = track.albumImageUrl?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    _lookupAttempts++;

    final artist = _primaryArtist(track.artists);
    if (artist.isEmpty) return null;

    final candidates = <String>{
      if ((track.albumName ?? '').trim().isNotEmpty) track.albumName!.trim(),
      track.name.trim(),
    };

    for (final candidate in candidates) {
      final cacheKey = '${artist.toLowerCase()}|${candidate.toLowerCase()}';
      final cached = _cachedValue(cacheKey);
      if (cached != null) {
        if (cached.isNotEmpty) return cached;
        continue;
      }

      final coverUrl = await _findCoverUrl(
        artist: artist,
        releaseOrTrack: candidate,
      );

      if (coverUrl == null || coverUrl.isEmpty) {
        _storeCachedValue(cacheKey, null, _missCacheTtl);
        continue;
      }

      _storeCachedValue(cacheKey, coverUrl, _hitCacheTtl);
      _lookupHits++;
      _maybePrintMetrics();
      return coverUrl;
    }

    _lookupMisses++;
    _maybePrintMetrics();
    return null;
  }

  Future<String?> _findCoverUrl({
    required String artist,
    required String releaseOrTrack,
  }) async {
    final cleaned = _normalizeTitle(releaseOrTrack);
    final artistQuery = _normalizeArtist(artist);
    final queries = <String>{
      cleaned,
      releaseOrTrack.trim(),
    }..removeWhere((q) => q.isEmpty);

    try {
      for (final q in queries) {
        final releaseIds = await _searchReleaseIds(artistQuery, q);
        for (final releaseId in releaseIds) {
          final url = await _coverUrlForReleaseId(releaseId);
          if (url != null) return url;
        }

        final releaseGroupIds = await _searchReleaseGroupIds(artistQuery, q);
        for (final releaseGroupId in releaseGroupIds) {
          final url = await _coverUrlForReleaseGroupId(releaseGroupId);
          if (url != null) return url;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _searchReleaseIds(
    String artist,
    String releaseName,
  ) async {
    final query = 'artist:"$artist" AND release:"$releaseName"';
    final uri = Uri.https('musicbrainz.org', '/ws/2/release', {
      'query': query,
      'fmt': 'json',
      'limit': '8',
    });

    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const [];

    final payload = jsonDecode(res.body) as Map<String, dynamic>;
    final releases = (payload['releases'] as List?) ?? const [];

    final ranked = releases
        .whereType<Map<String, dynamic>>()
        .where((release) => _score(release) >= _minimumScore)
        .toList()
      ..sort((a, b) => _score(b).compareTo(_score(a)));

    return ranked
        .map((release) => (release['id'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<String>> _searchReleaseGroupIds(
    String artist,
    String releaseName,
  ) async {
    final query = 'artist:"$artist" AND releasegroup:"$releaseName"';
    final uri = Uri.https('musicbrainz.org', '/ws/2/release-group', {
      'query': query,
      'fmt': 'json',
      'limit': '8',
    });

    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const [];

    final payload = jsonDecode(res.body) as Map<String, dynamic>;
    final releaseGroups = (payload['release-groups'] as List?) ?? const [];
    final ranked = releaseGroups
        .whereType<Map<String, dynamic>>()
        .where((release) => _score(release) >= _minimumScore)
        .toList()
      ..sort((a, b) => _score(b).compareTo(_score(a)));

    return ranked
        .map((group) => (group['id'] as String?)?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<String?> _coverUrlForReleaseId(String releaseId) async {
    final uri = Uri.parse('https://coverartarchive.org/release/$releaseId');
    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    return _extractCoverUrlFromPayload(
      res.body,
      fallbackId: releaseId,
      isRelease: true,
    );
  }

  Future<String?> _coverUrlForReleaseGroupId(String releaseGroupId) async {
    final uri =
        Uri.parse('https://coverartarchive.org/release-group/$releaseGroupId');
    final res = await http
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    return _extractCoverUrlFromPayload(
      res.body,
      fallbackId: releaseGroupId,
      isRelease: false,
    );
  }

  String? _extractCoverUrlFromPayload(
    String body, {
    required String fallbackId,
    required bool isRelease,
  }) {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final images = (payload['images'] as List?) ?? const [];

    for (final image in images.whereType<Map<String, dynamic>>()) {
      final isFront = image['front'] == true;
      if (!isFront) continue;

      final thumbs = image['thumbnails'] as Map<String, dynamic>?;
      final thumb250 = thumbs?['250'] as String?;
      if (thumb250 != null && thumb250.trim().isNotEmpty) {
        return thumb250.trim();
      }

      final thumbSmall = thumbs?['small'] as String?;
      if (thumbSmall != null && thumbSmall.trim().isNotEmpty) {
        return thumbSmall.trim();
      }

      final direct = image['image'] as String?;
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    }

    final base = isRelease ? 'release' : 'release-group';
    return 'https://coverartarchive.org/$base/$fallbackId/front-250';
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

  String _normalizeArtist(String value) {
    final first = value.split(',').first;
    return first
        .replaceAll(RegExp(r'\s+feat\.?.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _primaryArtist(String artists) {
    final first = artists.split(',').first.trim();
    return first;
  }

  void _maybePrintMetrics() {
    final completed = _lookupHits + _lookupMisses;
    if (completed == 0 || completed % _metricsPrintEvery != 0) return;

    final rate = (_lookupHits / completed * 100).toStringAsFixed(1);
    print(
      'CoverArtService metrics: attempts=$_lookupAttempts '
      'completed=$completed hits=$_lookupHits misses=$_lookupMisses hitRate=$rate%',
    );
  }

  int _score(Map<String, dynamic> payload) {
    return int.tryParse((payload['score'] ?? '0').toString()) ?? 0;
  }

  String? _cachedValue(String key) {
    final entry = _coverCache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _coverCache.remove(key);
      return null;
    }
    return entry.url;
  }

  void _storeCachedValue(String key, String? url, Duration ttl) {
    _coverCache[key] = _CacheEntry(
      url: url ?? '',
      expiresAt: DateTime.now().add(ttl),
    );
  }
}

class _CacheEntry {
  final String url;
  final DateTime expiresAt;

  _CacheEntry({
    required this.url,
    required this.expiresAt,
  });
}
