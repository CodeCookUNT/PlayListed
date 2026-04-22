import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class Track {
  final String name;
  final String artists;
  final int durationMs;
  final bool explicit;
  final String url;
  String? albumImageUrl;
  final int? popularity;
  final String? releaseDate;
  final String? id;
  final String? artistId;
  final double? score;
  final String? genre; // e.g. 'pop', 'hip hop', 'rock'

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
    this.genre,
  });
}

const _popArtistKeywords = [
  'taylor swift',
  'ariana grande',
  'ed sheeran',
  'dua lipa',
  'billie eilish',
  'harry styles',
  'the weeknd',
  'post malone',
  'selena gomez',
  'justin bieber',
  'lady gaga',
  'katy perry',
  'charlie puth',
  'shawn mendes',
  'camila cabello',
  'lizzo',
  'olivia rodrigo',
  'doja cat',
  'bts',
  'one direction',
  'miley cyrus',
  'sam smith',
  'sia',
  'halsey',
  'maroon 5',
  'carly rae jepsen',
  'meghan trainor',
  'bebe rexha',
  'ava max',
  'zara larsson',
];

const _hipHopArtistKeywords = [
  'drake',
  'kendrick lamar',
  'kanye west',
  'jay-z',
  'eminem',
  'lil wayne',
  'nicki minaj',
  'cardi b',
  'travis scott',
  'j. cole',
  'a\$ap rocky',
  'future',
  'young thug',
  'lil uzi vert',
  '21 savage',
  'chance the rapper',
  'mac miller',
  'childish gambino',
  'tyler the creator',
  'megan thee stallion',
  'roddy ricch',
  'dababy',
  'polo g',
  'lil baby',
  'gunna',
  'juice wrld',
  'xxxtentacion',
  'playboi carti',
  'trippie redd',
  'rick ross',
  'meek mill',
  'wiz khalifa',
  'snoop dogg',
  'ice cube',
];

const _rockArtistKeywords = [
  'queen',
  'the beatles',
  'led zeppelin',
  'rolling stones',
  'ac/dc',
  'nirvana',
  'foo fighters',
  'red hot chili peppers',
  'green day',
  'linkin park',
  'metallica',
  'guns n\' roses',
  'bon jovi',
  'u2',
  'coldplay',
  'radiohead',
  'the killers',
  'imagine dragons',
  'twenty one pilots',
  'fall out boy',
  'panic! at the disco',
  'my chemical romance',
  'blink-182',
  'paramore',
  'the strokes',
  'arctic monkeys',
  'muse',
  'system of a down',
  'rage against the machine',
  'pearl jam',
  'soundgarden',
  'alice in chains',
  'smashing pumpkins',
  'aerosmith',
  'def leppard',
];

String? _inferGenreFromArtist(String artists) {
  final lower = artists.toLowerCase();

  for (final kw in _hipHopArtistKeywords) {
    if (lower.contains(kw)) return 'hip hop';
  }
  for (final kw in _rockArtistKeywords) {
    if (lower.contains(kw)) return 'rock';
  }
  for (final kw in _popArtistKeywords) {
    if (lower.contains(kw)) return 'pop';
  }
  return null;
}

// Normalise whatever the CSV stores so it maps to our three buckets.
String? _normaliseGenre(String raw) {
  final lower = raw.toLowerCase().trim();
  if (lower.contains('hip hop') ||
      lower.contains('hip-hop') ||
      lower.contains('rap') ||
      lower.contains('trap') ||
      lower.contains('r&b') ||
      lower.contains('rnb')) {
    return 'hip hop';
  }
  if (lower.contains('rock') ||
      lower.contains('metal') ||
      lower.contains('punk') ||
      lower.contains('grunge') ||
      lower.contains('alternative') ||
      lower.contains('indie')) {
    return 'rock';
  }
  if (lower.contains('pop') ||
      lower.contains('dance') ||
      lower.contains('electro') ||
      lower.contains('synth')) {
    return 'pop';
  }
  return null;
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
  List<Track> _lowTracks = [];
  final Map<String, Track> _tracksById = {};
  int _nextSequentialIndex = 0;

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final highCsv = await rootBundle.loadString(_highPopularityPath);
    final lowCsv = await rootBundle.loadString(_lowPopularityPath);

    final highTracks = _parseCsv(highCsv);
    final lowTracks = _parseCsv(lowCsv);

    _popularTracks = highTracks;
    _lowTracks = lowTracks;
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

      final popularityCompare = (b.popularity ?? 0).compareTo(
        a.popularity ?? 0,
      );
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
      final popularityCompare = (b.popularity ?? 0).compareTo(
        a.popularity ?? 0,
      );
      if (popularityCompare != 0) return popularityCompare;
      return a.name.compareTo(b.name);
    });

    return _dedupe(matches).take(limit).toList();
  }


  Future<List<Track>> topSongs({String? yearRange, int limit = 50}) async {
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
        final popularityCompare = (b.popularity ?? 0).compareTo(
          a.popularity ?? 0,
        );
        if (popularityCompare != 0) return popularityCompare;
        return a.name.compareTo(b.name);
      });

    final deduped = _dedupe(sorted).take(limit).toList();

    for (final track in deduped) {
      if (track.id != null && track.albumImageUrl == null) {
        final imageUrl = await fetchAlbumImage(track.id!);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          track.albumImageUrl = imageUrl;
        }
      }
    }

    return deduped;
  }

  /// Returns top tracks filtered by genre bucket ('pop', 'hip hop', 'rock').
  /// Matching uses the parsed genre field first, then falls back to
  /// keyword-based artist inference.
  List<Track> topSongsByGenre(String genreBucket, {int limit = 15}) {
    final target = genreBucket.toLowerCase().trim();

    final matches =
        _allTracks.where((track) {
          final g = track.genre ?? _inferGenreFromArtist(track.artists);
          return g == target;
        }).toList()..sort((a, b) {
          final popularityCompare = (b.popularity ?? 0).compareTo(
            a.popularity ?? 0,
          );
          if (popularityCompare != 0) return popularityCompare;
          return a.name.compareTo(b.name);
        });

    return _dedupe(matches).take(limit).toList();
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
    }).toList()..shuffle(_random);

    if (pool.length <= limit) return pool;
    return pool.take(limit).toList();
  }

  List<Track> sequentialPopularSongs({
    int limit = 100,
    Set<String>? excludeIds,
    Set<String>? excludeNameArtist,
  }) {
    if (_popularTracks.isEmpty || limit <= 0) return [];

    final source = _popularTracks;
    final seenIds = <String>{...(excludeIds ?? {})};
    final seenNameArtist = <String>{...(excludeNameArtist ?? {})};
    final results = <Track>[];
    var index = _nextSequentialIndex;
    var scanned = 0;

    while (results.length < limit && scanned < source.length) {
      final track = source[index];
      final id = track.id;
      final key = '${track.name}|${track.artists}'.toLowerCase();

      if ((id == null || !seenIds.contains(id)) &&
          !seenNameArtist.contains(key)) {
        results.add(track);
        if (id != null && id.isNotEmpty) seenIds.add(id);
        seenNameArtist.add(key);
      }

      index = (index + 1) % source.length;
      scanned++;
    }

    _nextSequentialIndex = index;
    return results;
  }

   List<Track> sequentialLowPopSongs({
    int limit = 100,
    Set<String>? excludeIds,
    Set<String>? excludeNameArtist,
  }) {
    if (_lowTracks.isEmpty || limit <= 0) return [];

    final source = _lowTracks;
    final seenIds = <String>{...(excludeIds ?? {})};
    final seenNameArtist = <String>{...(excludeNameArtist ?? {})};
    final results = <Track>[];
    var index = _nextSequentialIndex;
    var scanned = 0;

    while (results.length < limit && scanned < source.length) {
      final track = source[index];
      final id = track.id;
      final key = '${track.name}|${track.artists}'.toLowerCase();

      if ((id == null || !seenIds.contains(id)) &&
          !seenNameArtist.contains(key)) {
        results.add(track);
        if (id != null && id.isNotEmpty) seenIds.add(id);
        seenNameArtist.add(key);
      }

      index = (index + 1) % source.length;
      scanned++;
    }

    _nextSequentialIndex = index;
    return results;
  }

  Future<String?> fetchAlbumImage(String trackId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('albumCovers')
          .doc(trackId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['albumImageUrl'] != null) {
          return data['albumImageUrl'] as String;
        }
      }
    } catch (e) {
      print('Error fetching album image for track $trackId: $e');
    }
    return null;
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

      final popularity = int.tryParse(
        _value(data, ['track_popularity', 'popularity']),
      );
      final releaseDate = _value(data, [
        'track_album_release_date',
        'release_date',
      ]);

      // Try to read genre from CSV; fall back to artist-keyword inference.
      final rawGenre = _value(data, ['playlist_genre', 'genre', 'track_genre']);
      final genre = rawGenre.isNotEmpty
          ? _normaliseGenre(rawGenre)
          : _inferGenreFromArtist(artists);

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
          genre: genre,
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
  static const String _musicBrainzBaseUrl = 'musicbrainz.org';
  static const String _coverArtBaseUrl = 'coverartarchive.org';
  static const String _musicBrainzUserAgent =
      'PlayListed/1.0 (https://github.com/)';

  Map<String, String> get _musicBrainzHeaders => {
    'User-Agent': _musicBrainzUserAgent,
    'Accept': 'application/json',
  };

  Future<bool> _verifyCoverArtUrl(String url) async {
    try {
      final response = await http.head(
        Uri.parse(url),
        headers: _musicBrainzHeaders,
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Cover Art Archive verification failed for $url: $e');
      return false;
    }
  }

  Future<String?> getAlbumImageFromAPI(Track track) async {
    if (track.name.trim().isEmpty || track.artists.trim().isEmpty) return null;

    final query = 'recording:"${track.name}" AND artist:"${track.artists}"';

    try {
      final response = await http.get(
        Uri.https(_musicBrainzBaseUrl, '/ws/2/recording', {
          'query': query,
          'fmt': 'json',
          'limit': '1',
        }),
        headers: _musicBrainzHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recordings = data['recordings'] as List?;
        if (recordings != null && recordings.isNotEmpty) {
          final releases = recordings.first['releases'] as List?;
          if (releases != null && releases.isNotEmpty) {
            final releaseId = releases.first['id'] as String?;
            if (releaseId != null && releaseId.isNotEmpty) {
              final coverUrl = Uri.https(
                _coverArtBaseUrl,
                '/release/$releaseId/front-250',
              ).toString();
              
              // Verify the cover actually exists in Cover Art Archive
              final exists = await _verifyCoverArtUrl(coverUrl);
              if (exists) {
                print('Found cover for "${track.name}" by ${track.artists}');
                return coverUrl;
              } else {
                print('Cover Art Archive has no image for release $releaseId ("${track.name}" by ${track.artists})');
              }
            }
          }
        }
      }
      else {
        print(
          'MusicBrainz API error for track "${track.name}" by ${track.artists}: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching album image for "${track.name}" by ${track.artists}: $e');
    }
    return null;
  }

  //get the album image from firestore, if not found get it from MusicBrainz
  //and Cover Art Archive and save it to firestore for future use
  Future<void> fetchAlbumImage(String accessToken, Track track) async {
    if (track.id == null || track.id!.isEmpty) {
      if (track.albumImageUrl == null || track.albumImageUrl!.isEmpty) {
        print('No cover for "${track.name}" by ${track.artists}: Track has no ID');
      }
      return;
    }

    try {
      // Always check firestore first (it's cached)
      final doc = await FirebaseFirestore.instance
          .collection('albumCovers')
          .doc(track.id)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['albumImageUrl'] != null) {
          track.albumImageUrl = data['albumImageUrl'];
          //print('Using cached cover for "${track.name}" by ${track.artists}');
          return;
        }
      }

      // No cache found, fetch from MusicBrainz/Cover Art Archive
      final coverUrl = await getAlbumImageFromAPI(track);
      if (coverUrl != null) {
        track.albumImageUrl = coverUrl;
        await setAlbumImageUrl(track.id!, coverUrl);
      } else {
        print('No cover available for "${track.name}" by ${track.artists}');
      }
    } catch (e) {
      print('Error in fetchAlbumImage for track ${track.id}: $e');
    }
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<String> getAccessToken() async {
    // Retained to keep existing call sites compatible.
    // MusicBrainz uses public endpoints and does not require OAuth.
    return 'musicbrainz-public-api';
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
    int noCoverCount = 0;

    //print seen ids
    for(var id in seenIds){
      print('Already seen track ID: $id');
    }

    Future<void> addUnique(Track track) async {
      final key = '${track.name}|${track.artists}'.toLowerCase();

      //if it is a recommended track, add it to the feed if it hasn't been liked yet
      if (track.id != null && track.id!.isNotEmpty) {
        if (seenIds.contains(track.id)) {
          return;
        }
        seenIds.add(track.id!);
      }

      if (seenNameArtist.contains(key)) return;
      seenNameArtist.add(key);
      await fetchAlbumImage(accessToken, track);
      if(track.albumImageUrl == null || track.albumImageUrl!.trim().isEmpty){
        noCoverCount++;
      }
      feed.add(track);
    }

    final validRec = recTracks.entries
        .where((entry) => entry.key.id != null && entry.key.id!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 1. Add ALL recommended tracks first (prioritized by score)
    print('fetchSongs: Adding ${validRec.length} recommended tracks to feed');
    for (final entry in validRec) {
      if(feed.length >= limit-4) break;
      await addUnique(entry.key);
    }
    print('fetchSongs: After recs, feed.length=${feed.length}');

    // 2. Add popular songs
    final popularTracks =
        _CsvMusicLibrary.instance.randomPopularSongs(limit: 3);
    print('fetchSongs: Adding ${popularTracks.length} popular tracks');
    for (final track in popularTracks) {
      await addUnique(track);
    }

    if (feed.length < limit) {
      final candidates = yearRange != null
          ? await _CsvMusicLibrary.instance.topSongs(
              yearRange: yearRange,
              limit: max(limit * 4, 40),
            )
          : _CsvMusicLibrary.instance.randomSongs(limit: max(limit * 4, 40));

      for (final track in candidates) {
        if (feed.length >= limit) break;
        await addUnique(track);
      }
    }

    if (feed.length < limit) {
      final fallback =
          _CsvMusicLibrary.instance.randomSongs(limit: limit * 3);
      for (final track in fallback) {
        if (feed.length >= limit) break;
        await addUnique(track);
      }
    }

    int recCount = feed.where((track) => recTracks.keys.any((rec) => rec.id == track.id)).length;
    print("Loaded ${feed.length} feed tracks with $noCoverCount missing covers");
    print("$recCount/$limit of them are from recommendations");
    

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

  /// Fetches the top [limit] tracks for a given genre bucket.
  /// [genre] should be one of: 'pop', 'hip hop', 'rock'.
  Future<List<Track>> fetchTopSongsByGenre(
    String genre, {
    int limit = 15,
  }) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.topSongsByGenre(genre, limit: limit);
  }

Future<List<Track>> searchSongs(String query, {int limit = 20}) async {
  await _CsvMusicLibrary.instance.ensureLoaded();

  final results =
      _CsvMusicLibrary.instance.searchSongs(query, limit: limit);

  // Optional: fetch album images (keeps your current behavior)
  final token = await getAccessToken();
  await Future.wait(results.map((t) => fetchAlbumImage(token, t)));

  return results;
}

Future<List<Track>> searchArtistTopSongs(
  String artistName, {
  int limit = 20,
}) async {
  await _CsvMusicLibrary.instance.ensureLoaded();

  final results = _CsvMusicLibrary.instance.searchArtistTopSongs(
    artistName,
    limit: limit,
  );

  final token = await getAccessToken();
  await Future.wait(results.map((t) => fetchAlbumImage(token, t)));

  return results;
}


  Track? _trackFromMusicBrainz(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return null;

    final artistCredit = (json['artist-credit'] as List?) ?? const [];
    final artists = artistCredit
        .map((entry) => (entry as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
    if (artists.isEmpty) return null;

    final releases = (json['releases'] as List?) ?? const [];
    final firstRelease = releases.isNotEmpty
        ? releases.first as Map<String, dynamic>
        : null;
    final releaseId = firstRelease?['id'] as String?;
    final releaseDate = firstRelease?['date'] as String?;
    final score = double.tryParse((json['score'] ?? '').toString());



    // Don't set albumImageUrl here - let fetchAlbumImage() verify it exists
    // This ensures Cover Art Archive actually has the image before storing the URL
    return Track(
      name: title,
      artists: artists,
      durationMs: (json['length'] as num?)?.toInt() ?? 0,
      explicit: false,
      url: 'https://musicbrainz.org/recording/${json['id']}',
      albumImageUrl: null,
      popularity: null,
      releaseDate: releaseDate,
      id: json['id'] as String?,
      artistId: null,
      score: score == null ? null : score / 100.0,
    );
  }

  Future<Track?> fetchTrackById(String trackId) async {
    await _CsvMusicLibrary.instance.ensureLoaded();
    return _CsvMusicLibrary.instance.trackById(trackId);
  }

  Future<Map<Track, double>> fetchRecommendedSongs() async {
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

      if (q1.docs.isEmpty) {
        print("fetchRecommendedSongs: No recommendations found for user $_uid");
        return {};
      }

      for (var doc in q1.docs) {
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

      print(
        "fetchRecommendedSongs: Fetched ${recommendedTracks.length} recommended tracks for user $_uid",
      );
    } catch (e) {
      print("Error fetching recommendations for user $_uid: $e");
    }
    return recommendedTracks;
  }

  Future<void> setAlbumImageUrl(String trackId, String albumImageUrl) async {
    if (trackId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('albumCovers')
          .doc(trackId)
          .set({'albumImageUrl': albumImageUrl}, SetOptions(merge: true));
    } catch (e) {
      print('Error setting album image URL for track $trackId: $e');
    }
  }
}
