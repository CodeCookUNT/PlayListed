import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_music_service.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'dart:async';
import 'track_artwork.dart';


class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final LocalMusicService _musicService = LocalMusicService();

  bool _isLoading = false;
  List<Track> _results = [];
  Timer? _searchDebounce;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {

    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    _doSearch();
  } 

  Future<void> _doSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final searches = await Future.wait([
        _musicService.searchSongs(query),
        _musicService.searchArtistTopSongs(query),
      ]);

      final songs = searches[0];
      final artistTracks = searches[1];

      final mergedResults = <Track>[];
      final seenKeys = <String>{};

      void addTrack(Track track) {
        final key = '${track.id ?? ''}|${track.name}|${track.artists}'
            .toLowerCase();
        if (seenKeys.add(key)) {
          mergedResults.add(track);
        }
      }

      for (final track in songs) {
        addTrack(track);
      }

      for (final track in artistTracks) {
        addTrack(track);
      }

      setState(() {
        _results = mergedResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Search error: $e');
    }
  }



  Future<void> _openSongInteraction(Track track) async {
    final appState = context.read<MyAppState>();
    final previousMainTrack = appState.current;
    
    appState.setCurrentTrack(track);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongInteractionPage(),
      ),
    );

    if (!mounted || previousMainTrack == null) return;
    appState.setCurrentTrack(previousMainTrack);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search for a song or artist',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _doSearch,
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            if (!_isLoading)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final track = _results[index];
                    return ListTile(
                      onTap: () => _openSongInteraction(track),
                      leading: TrackArtwork(
                        imageUrl: track.albumImageUrl,
                        width: 56,
                        height: 56,
                      ),
                      title: Text(track.name),
                      subtitle: Text(track.artists),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 16),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF1DB954),
                            child: IconButton(
                              icon: const Icon(Icons.open_in_new, color: Colors.white),
                              onPressed: track.url.isEmpty
                                  ? null
                                  : () async {
                                final uri = Uri.parse(track.url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  print('Could not launch ${track.url}');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SongInteractionPage extends StatelessWidget {
  const SongInteractionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MyAppState>(
      builder: (context, appState, _) {
        final isDark = appState.isDarkMode;
        final vinyl = appState.vinylColor;

        final gradientTop = isDark
            ? Color.alphaBlend(vinyl.withOpacity(0.40), const Color(0xFF0A1628))
            : Color.alphaBlend(vinyl.withOpacity(0.50), Colors.white);
        final gradientBottom = isDark
            ? const Color(0xFF0A1628)
            : Colors.white;

        final barColors = isDark
            ? [const Color(0xFF0A2233), const Color(0xFF1583B7)]
            : [const Color.fromARGB(255, 31, 139, 189), const Color.fromARGB(255, 57, 27, 190)];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: barColors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: Text(
              'Playlist\'d',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [gradientTop, gradientBottom],
              ),
            ),
            child: const GeneratorPage(
              showScrollButtons: false,
              centerVertically: true,
            ),
          ),
        );
      },
    );
  }
}