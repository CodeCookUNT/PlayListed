import 'package:flutter/material.dart';
import 'local_music_service.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'search.dart';
import 'loading_vinyl.dart';
import 'track_artwork.dart';

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

// Color bars shown behind each decade/category title.
// Each entry is a list of 2 colors that form a gradient strip.
const Map<String, List<Color>> _decadeColors = {
  'Popular Now': [Color(0xFF1DB954), Color(0xFF1583B7)],
  '2020s': [Color(0xFF6C63FF), Color(0xFFE040FB)],
  '2010s': [Color(0xFFFF6B35), Color(0xFFFFD700)],
  '2000s': [Color(0xFF00CFDD), Color(0xFF005BEA)],
  '90s':   [Color(0xFFFF0080), Color(0xFF7928CA)],
  '80s':   [Color(0xFFFF6EC7), Color(0xFFFFD700)],
  '70s':   [Color(0xFFD4A017), Color(0xFFB5451B)],
  '60s':   [Color(0xFF43B89C), Color(0xFFE8A838)],
  '50s':   [Color(0xFF708090), Color(0xFFB0C4DE)],
};

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final LocalMusicService _spotifyService = LocalMusicService();
  final SpotifyCache _cache = SpotifyCache();

  String? _accessToken;
  bool _loading = true;
  String? _selectedTrackId;

  String? _expandedCategory;

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
        _spotifyService.fetchTopSongs(_accessToken, limit: 15).then((tracks) {
          _cache.decadeTracks['Popular Now'] = tracks;
        }),
      );

      // fetch 15 songs for each decade
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
                limit: 15,
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
            ? const Color(0xFF101417)
            : const Color(0xFFF6FAFE),
        body: _loading
            ? const LoadingVinylPage(
                labelText: 'Loading collections...',
                ringText: ' LOADING COLLECTIONS ',
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: _cache.decadeTracks.entries.map((entry) {
                  // Popular Now is always expanded
                  final isPopularNow = entry.key == 'Popular Now';
                  return _CollectionRow(
                    title: entry.key,
                    tracks: entry.value,
                    selectedTrackId: _selectedTrackId,
                    isExpanded: isPopularNow
                        ? true
                        : _expandedCategory == entry.key,
                    onHeaderTapped: () {
                      if (isPopularNow) return; // cannot collapse Popular Now
                      setState(() {
                        if (_expandedCategory == entry.key) {
                          _expandedCategory = null;
                        } else {
                          _expandedCategory = entry.key;
                        }
                      });
                    },
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

  final bool isExpanded;
  final VoidCallback onHeaderTapped;

  const _CollectionRow({
    required this.title,
    required this.tracks,
    required this.selectedTrackId,
    required this.onTrackTapped,
    required this.isExpanded,
    required this.onHeaderTapped,
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

    final colors = _decadeColors[widget.title] ?? [const Color(0xFF1583B7)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: widget.onHeaderTapped,
            child: SizedBox(
              height: 32,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                              ),
                        ),
                        if (widget.title != 'Popular Now')
                          Icon(
                            widget.isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.isExpanded)
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
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
      onTap: () async {
        final appState = context.read<MyAppState>();
        final previousMainTrack = appState.current;

        appState.setCurrentTrack(track);
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SongInteractionPage(),
          ),
        );

        if (previousMainTrack == null) return;
        appState.setCurrentTrack(previousMainTrack);
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
            Positioned.fill(
              child: TrackArtwork(
                imageUrl: track.albumImageUrl,
                width: 180,
                height: 180,
                borderRadius: 0,
                icon: Icons.album,
                backgroundColor: Colors.grey.shade800,
                iconColor: Colors.white54,
              ),
            ),
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