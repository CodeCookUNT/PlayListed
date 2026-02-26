import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'spotify.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'search.dart';

//cache so the data stays loaded when switching pages
class SpotifyCache {
  static final SpotifyCache _instance = SpotifyCache._internal();
  factory SpotifyCache() => _instance;
  SpotifyCache._internal();

  final Map<String, List<Track>> decadeTracks = {
    'Popular Now': [],
    '2020s': [],
    '2010s': [],
    '2000s': [],
    '90s': [],
    '80s': [],
    '70s': [],
    '60s': [],
    '50s': [],
  };

  bool isLoaded = false;

  void clear() {
    for (var key in decadeTracks.keys) {
      decadeTracks[key] = [];
    }
    isLoaded = false;
  }
}

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final SpotifyService _spotifyService = SpotifyService();
  final SpotifyCache _cache = SpotifyCache();

  String? _accessToken;
  bool _loading = true;
  String? _selectedTrackId;

  @override
  void initState() {
    super.initState();
    _loadSpotifyData();
  }

  Future<void> _loadSpotifyData() async {
    if (_cache.isLoaded) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      _accessToken = await _spotifyService.getAccessToken();
      final futures = <Future<void>>[];

      futures.add(
        _spotifyService.fetchTopSongs(_accessToken, limit: 50).then((tracks) {
          _cache.decadeTracks['Popular Now'] = tracks;
        }),
      );

      // fetch 50 songs for each decade
      final decades = {
        '2020s': '2020-2029',
        '2010s': '2010-2019',
        '2000s': '2000-2009',
        '90s': '1990-1999',
        '80s': '1980-1989',
        '70s': '1970-1979',
        '60s': '1960-1969',
        '50s': '1950-1959',
      };

      for (var entry in decades.entries) {
        futures.add(
          _spotifyService
              .fetchTopSongs(
                _accessToken,
                yearRange: entry.value,
                limit: 50,
              )
              .then((tracks) {
            _cache.decadeTracks[entry.key] = tracks;
          }),
        );
      }

      //await Future.wait(futures);
      for (final future in futures) {
        await future;
        await Future.delayed(const Duration(milliseconds: 250));
    }
      _cache.isLoaded = true;

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('Spotify load error: $e');

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _onTrackTapped(String? trackId) {
    setState(() {
      _selectedTrackId = _selectedTrackId == trackId ? null : trackId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color.fromARGB(255, 66, 66, 66)
            : Colors.white,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: _cache.decadeTracks.entries.map((entry) {
                  return _CollectionRow(
                    title: entry.key,
                    tracks: entry.value,
                    selectedTrackId: _selectedTrackId,
                    onTrackTapped: _onTrackTapped,
                  );
                }).toList(),
              ),
      ),
    );
  }
}

// Displays a horizontal list of album covers for a decade/category
class _CollectionRow extends StatefulWidget {
  final String title;
  final List<Track> tracks;
  final String? selectedTrackId;
  final Function(String?) onTrackTapped;

  const _CollectionRow({
    required this.title,
    required this.tracks,
    required this.selectedTrackId,
    required this.onTrackTapped,
  });

  @override
  State<_CollectionRow> createState() => _CollectionRowState();
}

class _CollectionRowState extends State<_CollectionRow> {
  final ScrollController _scrollController = ScrollController();

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 300,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 300,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
          ),
        ),
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                scrollDirection: Axis.horizontal,
                itemCount: widget.tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _AlbumCover(
                    track: widget.tracks[index],
                    isSelected:
                        widget.selectedTrackId == widget.tracks[index].id,
                    onTap: () =>
                        widget.onTrackTapped(widget.tracks[index].id),
                  );
                },
              ),
              // Left Arrow
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left, size: 32),
                    color: Colors.black,
                    onPressed: _scrollLeft,
                  ),
                ),
              ),
              // Right Arrow
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 32),
                    color: Colors.black,
                    onPressed: _scrollRight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AlbumCover extends StatelessWidget {
  final Track track;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlbumCover({
    required this.track,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<MyAppState>().setCurrentTrack(track);

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SongInteractionPage(),
          ),
        );
      },
      child: Container(
        width: 180,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // Album image
            Positioned.fill(
              child: track.albumImageUrl != null &&
                      track.albumImageUrl!.isNotEmpty
                  ? Image.network(track.albumImageUrl!,
                      fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.album,
                          size: 48, color: Colors.white54),
                    ),
            ),

            // Title overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      track.artists,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}