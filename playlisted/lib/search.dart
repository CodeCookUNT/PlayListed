import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'searchfunctions.dart';
import 'spotify.dart';
import 'package:provider/provider.dart';
import 'main.dart';


class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final SearchFunctions _searchFunctions = SearchFunctions();

  bool _isLoading = false;
  List<Track> _results = [];

  Future<void> _doSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      // Try song search first
      final songs = await _searchFunctions.searchSongs(query);

      if (songs.isNotEmpty) {
        setState(() {
          _results = songs;
          _isLoading = false;
        });
        return;
      }

      final artistTracks = await _searchFunctions.searchArtistTopSongs(query);

      setState(() {
        _results = artistTracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Search error: $e');
    }
  }

void _openSongInteraction(Track track) {
    context.read<MyAppState>().setCurrentTrack(track);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongInteractionPage(),
      ),
    );
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
                      leading: track.albumImageUrl != null
                          ? Image.network(track.albumImageUrl!)
                          : const Icon(Icons.music_note),
                      title: Text(track.name),
                      subtitle: Text(track.artists),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 16),
                          if (track.url != null)
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1DB954),
                              child: IconButton(
                                icon: const Icon(Icons.open_in_new, color: Colors.white),
                                onPressed: () async {
                                  final uri = Uri.parse(track.url!);
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
    return Scaffold(
      appBar: AppBar(title: const Text('PlayListed')),
      body: Container(
        color: context.watch<MyAppState>().backgroundColor,
        child: GeneratorPage(),
      ),
    );
  }
}