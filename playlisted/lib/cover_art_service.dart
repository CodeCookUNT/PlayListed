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
  bool _debugLoggingEnabled = false;

  void setDebugLogging(bool enabled) {
    _debugLoggingEnabled = enabled;
  }

  Future<String?> resolveForTrack(Track track) async {
    final existing = track.albumImageUrl?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    _lookupAttempts++;

    final artist = _primaryArtist(track.artists);
    if (artist.isEmpty) return null;
    final expectedYear = _extractYear(track.releaseDate);

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
        expectedYear: expectedYear,
      );

      if (coverUrl == null || coverUrl.isEmpty) {
        _debug('miss candidate="$candidate" artist="$artist"');
        _storeCachedValue(cacheKey, null, _missCacheTtl);
        continue;
      }

      _debug('hit candidate="$candidate" artist="$artist" -> $coverUrl');
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
    int? expectedYear,
  }) async {
    final cleaned = _normalizeTitle(releaseOrTrack);
    final artistQuery = _normalizeArtist(artist);
    final queries = <String>{
      cleaned,
      releaseOrTrack.trim(),
    }..removeWhere((q) => q.isEmpty);

    try {
      for (final q in queries) {
        final releaseIds = await _searchReleaseIds(
          artistQuery,
          q,
          expectedYear: expectedYear,
        );
        for (final release in releaseIds) {
          final url = await _coverUrlForReleaseId(release.id);
          if (url != null) return url;
        }

        final releaseGroupIds = await _searchReleaseGroupIds(
          artistQuery,
          q,
          expectedYear: expectedYear,
        );
        for (final releaseGroup in releaseGroupIds) {
          final url = await _coverUrlForReleaseGroupId(releaseGroup.id);
          if (url != null) return url;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<_RankedId>> _searchReleaseIds(
    String artist,
    String releaseName,
    {
    int? expectedYear,
  }
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
        .map((release) {
          final id = (release['id'] as String?)?.trim() ?? '';
          final title = (release['title'] as String?) ?? '';
          final year = _extractYear(release['date'] as String?);
          final quality = _score(release) +
              _titleMatchBonus(title, releaseName) +
              _yearMatchBonus(year, expectedYear);
          return _RankedId(id: id, quality: quality);
        })
        .where((candidate) => candidate.id.isNotEmpty)
        .toList()
      ..sort((a, b) => b.quality.compareTo(a.quality));

    return ranked;
  }

  Future<List<_RankedId>> _searchReleaseGroupIds(
    String artist,
    String releaseName,
    {
    int? expectedYear,
  }
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
        .map((group) {
          final id = (group['id'] as String?)?.trim() ?? '';
          final title = (group['title'] as String?) ?? '';
          final year = _extractYear(
            (group['first-release-date'] as String?) ??
                (group['date'] as String?),
          );
          final quality = _score(group) +
              _titleMatchBonus(title, releaseName) +
              _yearMatchBonus(year, expectedYear);
          return _RankedId(id: id, quality: quality);
        })
        .where((candidate) => candidate.id.isNotEmpty)
        .toList()
      ..sort((a, b) => b.quality.compareTo(a.quality));

    return ranked;
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

  int _titleMatchBonus(String foundTitle, String wantedTitle) {
    final found = _normalizeTitle(foundTitle).toLowerCase();
    final wanted = _normalizeTitle(wantedTitle).toLowerCase();
    if (found.isEmpty || wanted.isEmpty) return 0;
    if (found == wanted) return 25;
    if (found.contains(wanted) || wanted.contains(found)) return 12;
    return 0;
  }

  int _yearMatchBonus(int? foundYear, int? expectedYear) {
    if (foundYear == null || expectedYear == null) return 0;
    if (foundYear == expectedYear) return 10;
    if ((foundYear - expectedYear).abs() == 1) return 4;
    return 0;
  }

  int? _extractYear(String? dateValue) {
    if (dateValue == null || dateValue.length < 4) return null;
    return int.tryParse(dateValue.substring(0, 4));
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

  void _debug(String message) {
    if (!_debugLoggingEnabled) return;
    print('CoverArtService debug: $message');
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

class _RankedId {
  final String id;
  final int quality;

  _RankedId({
    required this.id,
    required this.quality,
  });
}
