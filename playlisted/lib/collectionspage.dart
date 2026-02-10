import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart' show MyAppState;
import 'spotify.dart';

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
        _spotifyService
            .fetchTopSongs(_accessToken, limit: 50)
            .then((tracks) {
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

      await Future.wait(futures);
      _cache.isLoaded = true;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint('Spotify load error: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  void _onTrackTapped(String? trackId) {
    setState(() {
      _selectedTrackId =
          _selectedTrackId == trackId ? null : trackId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();

    return SafeArea(
      child: Scaffold(
        backgroundColor: appState.backgroundColor,
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 40),
                scrollDirection: Axis.horizontal,
                itemCount: widget.tracks.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _AlbumCover(
                    track: widget.tracks[index],
                    isSelected: widget.selectedTrackId ==
                        widget.tracks[index].id,
                    onTap: () => widget
                        .onTrackTapped(widget.tracks[index].id),
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
                    icon: const Icon(Icons.chevron_left,
                        size: 32),
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
                    icon: const Icon(Icons.chevron_right,
                        size: 32),
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
      onTap: onTap,
      child: Container(
        width: 180,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // Album Cover Image
            Positioned.fill(
              child: track.albumImageUrl != null &&
                      track.albumImageUrl!.isNotEmpty
                  ? Image.network(
                      track.albumImageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint(
                            'Error loading image for ${track.name}: $error');
                        return const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.white54,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.album,
                          size: 48,
                          color: Colors.white54),
                    ),
            ),
            // Overlay with song info
            if (isSelected)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        maxLines: 3,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.artists,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70),
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
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
