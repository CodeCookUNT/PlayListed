import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

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

class _CsvMusicLibrary {
  _CsvMusicLibrary._();

  static final _CsvMusicLibrary instance = _CsvMusicLibrary._();
  static const String _highPopularityPath =
      'lib/Data/high_popularity_spotify_data.csv';
  static const String _lowPopularityPath =
      'lib/Data/low_popularity_spotify_data.csv';

  final Random _random = Random();
  bool _loaded = false;
  List<Track> _allTracks = [];
  List<Track> _popularTracks = [];
  final Map<String, Track> _tracksById = {};

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final highCsv = await rootBundle.loadString(_highPopularityPath);
    final lowCsv = await rootBundle.loadString(_lowPopularityPath);

    final highTracks = _parseCsv(highCsv);
    final lowTracks = _parseCsv(lowCsv);

    _popularTracks = highTracks;
    _allTracks = [...highTracks, ...lowTracks];

    for (final track in _allTracks) {
      final id = track.id;
      if (id != null && id.isNotEmpty) {
        _tracksById[id] = track;
      }
    }

    _loaded = true;
  }

  Track? trackById(String trackId) => _tracksById[trackId];

  List<Track> searchSongs(String query, {int limit = 20}) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final matches = _allTracks.where((track) {
      return track.name.toLowerCase().contains(normalized) ||
          track.artists.toLowerCase().contains(normalized);
    }).toList();

    matches.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(normalized) ? 1 : 0;
      final bStarts = b.name.toLowerCase().startsWith(normalized) ? 1 : 0;
      if (aStarts != bStarts) return bStarts.compareTo(aStarts);

      final popularityCompare =
          (b.popularity ?? 0).compareTo(a.popularity ?? 0);
      if (popularityCompare != 0) return popularityCompare;

      return a.name.compareTo(b.name);
    });

    return _dedupe(matches).take(limit).toList();
  }

  List<Track> searchArtistTopSongs(String artistName, {int limit = 20}) {
    final normalized = artistName.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final matches = _allTracks.where((track) {
      return track.artists
          .toLowerCase()
          .split(',')
          .map((artist) => artist.trim())
          .any((artist) => artist.contains(normalized));
    }).toList();

    matches.sort((a, b) {
      final popularityCompare =
          (b.popularity ?? 0).compareTo(a.popularity ?? 0);
      if (popularityCompare != 0) return popularityCompare;
      return a.name.compareTo(b.name);
    });

    return _dedupe(matches).take(limit).toList();
  }

  List<Track> topSongs({String? yearRange, int limit = 50}) {
    Iterable<Track> source = _allTracks;

    if (yearRange != null) {
      final bounds = _parseYearRange(yearRange);
      if (bounds != null) {
        source = source.where((track) {
          final year = _extractYear(track.releaseDate);
          return year != null && year >= bounds.$1 && year <= bounds.$2;
        });
      }
    }

    final sorted = source.toList()
      ..sort((a, b) {
        final popularityCompare =
            (b.popularity ?? 0).compareTo(a.popularity ?? 0);
        if (popularityCompare != 0) return popularityCompare;
        return a.name.compareTo(b.name);
      });

    return _dedupe(sorted).take(limit).toList();
  }

  List<Track> randomPopularSongs({int limit = 10, Set<String>? excludeIds}) {
    return _randomTracks(
      source: _popularTracks.isEmpty ? _allTracks : _popularTracks,
      limit: limit,
      excludeIds: excludeIds,
    );
  }

  List<Track> randomSongs({int limit = 10, Set<String>? excludeIds}) {
    return _randomTracks(
      source: _allTracks,
      limit: limit,
      excludeIds: excludeIds,
    );
  }

  List<Track> _randomTracks({
    required List<Track> source,
    required int limit,
    Set<String>? excludeIds,
  }) {
    if (source.isEmpty || limit <= 0) return [];

    final pool = source.where((track) {
      final id = track.id;
      return id == null || !(excludeIds?.contains(id) ?? false);
    }).toList()
      ..shuffle(_random);

    if (pool.length <= limit) return pool;
    return pool.take(limit).toList();
  }

  List<Track> _parseCsv(String rawCsv) {
    final rows = rawCsv
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (rows.isEmpty) return [];

    final headers = _parseCsvLine(rows.first);
    final tracks = <Track>[];

    for (final row in rows.skip(1)) {
      final values = _parseCsvLine(row);
      if (values.isEmpty) continue;

      final data = <String, String>{};
      for (int i = 0; i < headers.length && i < values.length; i++) {
        data[headers[i]] = values[i];
      }

      final id = _value(data, ['id', 'track_id']);
      final trackName = _value(data, ['track_name', 'name']);
      final artists = _value(data, ['track_artist', 'artists']);
      if (trackName.isEmpty || artists.isEmpty) continue;

      final popularity =
          int.tryParse(_value(data, ['track_popularity', 'popularity']));
      final releaseDate = _value(
        data,
        ['track_album_release_date', 'release_date'],
      );

      tracks.add(
        Track(
          name: trackName,
          artists: artists,
          durationMs: _parseInt(_value(data, ['duration_ms'])) ?? 0,
          explicit: _parseBool(_value(data, ['explicit'])),
          url: id.isEmpty ? '' : 'https://open.spotify.com/track/$id',
          albumImageUrl: null,
          popularity: popularity,
          releaseDate: releaseDate.isEmpty ? null : releaseDate,
          id: id.isEmpty ? null : id,
          artistId: null,
          score: popularity == null ? null : popularity / 100.0,
        ),
      );
    }

    return tracks;
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final isEscapedQuote =
            inQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (isEscapedQuote) {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }

    values.add(current.toString().trim());
    return values;
  }

  String _value(Map<String, String> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  int? _parseInt(String value) {
    if (value.isEmpty) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  bool _parseBool(String value) {
    return value.trim().toLowerCase() == 'true';
  }

  (int, int)? _parseYearRange(String yearRange) {
    final parts = yearRange.split('-');
    if (parts.length != 2) return null;

    final start = int.tryParse(parts[0]);
    final end = int.tryParse(parts[1]);
    if (start == null || end == null) return null;

    return (start, end);
  }

  int? _extractYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.length < 4) return null;
    return int.tryParse(releaseDate.substring(0, 4));
  }

  List<Track> _dedupe(List<Track> tracks) {
    final seen = <String>{};
    final unique = <Track>[];

    for (final track in tracks) {
      final key = '${track.name}|${track.artists}'.toLowerCase();
      if (seen.add(key)) {
        unique.add(track);
      }
    }

    return unique;
  }
}

class LocalMusicService {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<String> getAccessToken() async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return 'local-csv';
  }

  Future<List<Track>> fetchSongs(
    String accessToken,
    Map<Track, double> recTracks, {
    String? yearRange,
    int limit = 10,
    Set<String>? excludeIds,
    Set<String>? excludeNameArtist,
  }) async {
    await _CsvMusicLibrary.instance.ensureLoaded();

    final seenIds = <String>{...(excludeIds ?? {})};
    final seenNameArtist = <String>{...(excludeNameArtist ?? {})};
    final feed = <Track>[];

    void addUnique(Track track) {
      final key = '${track.name}|${track.artists}'.toLowerCase();

      if (track.id != null && track.id!.isNotEmpty) {
        if (seenIds.contains(track.id)) return;
        seenIds.add(track.id!);
      }

      if (seenNameArtist.contains(key)) return;
      seenNameArtist.add(key);
      feed.add(track);
    }
  
    final validRec = recTracks.entries
        .where((entry) => entry.key.id != null && entry.key.id!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in validRec) {
      if (feed.length >= 8) break;
      addUnique(entry.key);
    }

    if (feed.length < 8) {
      final extraRecommendations =
          _CsvMusicLibrary.instance.randomSongs(limit: 8 - feed.length);
      for (final track in extraRecommendations) {
        if (feed.length >= 8) break;
        addUnique(track);
      }
    }

    final popularTracks = _CsvMusicLibrary.instance.randomPopularSongs(limit: 3);
    for (final track in popularTracks) {
      addUnique(track);
    }

    if (feed.length < limit) {
      final candidates = yearRange != null
          ? _CsvMusicLibrary.instance.topSongs(
              yearRange: yearRange,
              limit: max(limit * 4, 40),
            )
          : _CsvMusicLibrary.instance.randomSongs(limit: max(limit * 4, 40));

      for (final track in candidates) {
        if (feed.length >= limit) break;
        addUnique(track);
      }
    }

    if (feed.length < limit) {
      final fallback = _CsvMusicLibrary.instance.randomSongs(limit: limit * 3);
      for (final track in fallback) {
        if (feed.length >= limit) break;
        addUnique(track);
      }
    }

    feed.shuffle();
    return feed.take(limit).toList();
  }

  Future<List<Track>> getRandomPopSongs({int limit = 10}) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.randomPopularSongs(limit: limit);
  }

  Future<List<Track>> fetchTopSongs(
    String? accessToken, {
    String? yearRange,
    int limit = 500,
  }) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.topSongs(
      yearRange: yearRange,
      limit: limit,
    );
  }

  Future<List<Track>> searchSongs(String query, {int limit = 20}) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.searchSongs(query, limit: limit);
  }

  Future<List<Track>> searchArtistTopSongs(
    String artistName, {
    int limit = 20,
  }) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.searchArtistTopSongs(
      artistName,
      limit: limit,
    );
  }

  Future<Track?> fetchTrackById(String trackId) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.trackById(trackId);
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
