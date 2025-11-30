import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'searchfunctions.dart';
import 'spotify.dart';

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
      List<Track> songs = await _searchFunctions.searchSongs(query);

      if (songs.isNotEmpty) {
        setState(() {
          _results = songs;
          _isLoading = false;
        });
        return;
      }

      // Otherwise try artist search
      List<Track> artistTracks =
          await _searchFunctions.searchArtistTopSongs(query);

      setState(() {
        _results = artistTracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print("Search error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Music")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Search for a song or artist",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _doSearch,
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: CircularProgressIndicator()),

            if (!_isLoading)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final track = _results[index];
                    return ListTile(
                      leading: track.albumImageUrl != null
                          ? Image.network(track.albumImageUrl!)
                          : const Icon(Icons.music_note),
                      title: Text(track.name),
                      subtitle: Text(track.artists),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 16),
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
