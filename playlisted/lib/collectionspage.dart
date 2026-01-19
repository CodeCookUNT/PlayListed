import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart' show MyAppState;
import 'spotify.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  final SpotifyService _spotifyService = SpotifyService();

  String? _accessToken;
  bool _loading = true;
  String? _selectedTrackId;

  final Map<String, List<Track>> decadeTracks = {
    '60s': [],
    '70s': [],
    '80s': [],
    '90s': [],
    '2000s': [],
    '2010s': [],
    '2020s': [],
  };

  @override
  void initState() {
    super.initState();
    _loadSpotifyData();
  }

  Future<void> _loadSpotifyData() async {
    try {
      _accessToken = await _spotifyService.getAccessToken();

      // Fetch 50 songs for each decade
      final decades = {
        '60s': '1960-1969',
        '70s': '1970-1979',
        '80s': '1980-1989',
        '90s': '1990-1999',
        '2000s': '2000-2009',
        '2010s': '2010-2019',
        '2020s': '2020-2029',
      };

      for (var entry in decades.entries) {
        try {
          final tracks = await _spotifyService.fetchTopSongs(
            _accessToken,
            yearRange: entry.value,
            limit: 50,
          );
          decadeTracks[entry.key] = tracks;
          debugPrint('${entry.key}: Fetched ${tracks.length} tracks');
        } catch (e) {
          debugPrint('Error fetching ${entry.key}: $e');
        }
      }

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
      if (_selectedTrackId == trackId) {
        _selectedTrackId = null;
      } else {
        _selectedTrackId = trackId;
      }
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
                children: decadeTracks.entries.map((entry) {
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

class _CollectionRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _AlbumCover(
                track: tracks[index],
                isSelected: selectedTrackId == tracks[index].id,
                onTap: () => onTrackTapped(tracks[index].id),
              );
            },
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
        width: 140,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(4, 4),
            ),
          ],
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
                      child: Icon(
                        Icons.album,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
            ),
            // Overlay with song info
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.artists,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade300,
                        ),
                        maxLines: 2,
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