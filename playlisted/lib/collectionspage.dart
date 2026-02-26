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
                padding: const EdgeInsets.symmetric(horizontal: 40),
                scrollDirection: Axis.horizontal,
                itemCount: widget.tracks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _AlbumCover(
                    track: widget.tracks[index],
                    isSelected: widget.selectedTrackId == widget.tracks[index].id,
                    onTap: () => widget.onTrackTapped(widget.tracks[index].id),
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

class _AlbumCover extends StatefulWidget {
  final Track track;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlbumCover({
    required this.track,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AlbumCover> createState() => _AlbumCoverState();
}

class _AlbumCoverState extends State<_AlbumCover> {
  bool _isFavorite = false;
  double _userRating = 0.0;
  String _review = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final trackId = widget.track.id;
    if (userId == null || trackId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(trackId)
        .get();

    if (!mounted || !doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    setState(() {
      _isFavorite = data['favorite'] == true;
      _userRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      _review = data['review'] ?? '';
    });
  }

  Future<void> _toggleFavorite() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final trackId = widget.track.id;
    if (userId == null || trackId == null || _saving) return;

    setState(() {
      _saving = true;
    });

    final nextValue = !_isFavorite;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(trackId)
        .set({
      'favorite': nextValue,
      'name': widget.track.name,
      'artists': widget.track.artists,
      'albumImageUrl': widget.track.albumImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _isFavorite = nextValue;
      _saving = false;
    });
  }

  Future<void> _updateRating(double newRating) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final trackId = widget.track.id;
    if (userId == null || trackId == null || _saving) return;

    setState(() {
      _userRating = newRating;
      _saving = true;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(trackId)
        .set({
      'rating': newRating,
      'name': widget.track.name,
      'artists': widget.track.artists,
      'albumImageUrl': widget.track.albumImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _saving = false;
    });
  }

  Future<void> _updateReview(String reviewText) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final trackId = widget.track.id;
    if (userId == null || trackId == null || _saving) return;

    setState(() {
      _review = reviewText;
      _saving = true;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(trackId)
        .set({
      'review': reviewText,
      'name': widget.track.name,
      'artists': widget.track.artists,
      'albumImageUrl': widget.track.albumImageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _saving = false;
    });
  }

  Future<void> _showReviewDialog() async {
    final controller = TextEditingController(text: _review);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Write a Review"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: "Type your review..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await _updateReview(controller.text);
              Navigator.pop(context);
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<MyAppState>().setCurrentTrack(widget.track);

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
            // Album Cover Image
            Positioned.fill(
              child: widget.track.albumImageUrl != null &&
                      widget.track.albumImageUrl!.isNotEmpty
                  ? Image.network(widget.track.albumImageUrl!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.album, size: 48, color: Colors.white54),
                    ),
            ),

            //shows song name and artist info at the bottom of a song
            if (!widget.isSelected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                        widget.track.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.track.artists,
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

            // Overlay with song info
            //currently unused, keeping if we pivot back to on album review method
            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                ),
              ),
            if (widget.isSelected)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.track.artists,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final starValue = index + 1.0;
                        return IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _userRating >= starValue ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          ),
                          onPressed: () => _updateRating(starValue),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red, size: 22),
                          onPressed: _toggleFavorite,
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _showReviewDialog,
                          child: const Text("Review", style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, color: Colors.white),
                          onPressed: () async {
                            final uri = Uri.parse(widget.track.url!);
                            if (await canLaunch(uri.toString())) {
                              await launch(uri.toString());
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
