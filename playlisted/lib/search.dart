import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'searchfunctions.dart';
import 'spotify.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'content_filter.dart';
import 'favorites.dart';
import 'globalratings.dart';


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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SongInteractionPage(track: track),
                          ),
                        );
                      },
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

class SongInteractionPage extends StatefulWidget {
  final Track track;

  const SongInteractionPage({super.key, required this.track});

  @override
  State<SongInteractionPage> createState() => _SongInteractionPageState();
}

class _SongInteractionPageState extends State<SongInteractionPage> {
  bool _isFavorite = false;
  bool _isSaved = false;
  double _userRating = 0.0;

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
    });
  }

  Future<void> _saveRating(double newRating) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final trackId = widget.track.id;

    if (userId == null || trackId == null) return;

    setState(() {
      _userRating = newRating;
    });

    await Favorites.instance.setRating(
      trackId: trackId,
      name: widget.track.name,
      artists: widget.track.artists,
      albumImageUrl: widget.track.albumImageUrl,
      rating: newRating,
    );

    if (newRating <= 0) {
      await GlobalRatings.instance.removeRating(trackId: trackId, userId: userId);
    } else {
      await GlobalRatings.instance.submitRating(
        trackId: trackId,
        userId: userId,
        rating: newRating,
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final trackId = widget.track.id;
    if (trackId == null || _isSaved) return;

    setState(() {
      _isSaved = true;
    });

    final nextValue = !_isFavorite;
    await Favorites.instance.setFavorite(
      trackId: trackId,
      name: widget.track.name,
      artists: widget.track.artists,
      albumImageUrl: widget.track.albumImageUrl,
      favorite: nextValue,
    );

    if (mounted) {
      setState(() {
        _isFavorite = nextValue;
        _isSaved = false;
      });
    }
  }

  Future<void> _showReviewDialog() async {
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final trackId = widget.track.id;
    if (userId == null || trackId == null) return;

    String existingReview = '';
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(trackId)
        .get();

    if (doc.exists && doc.data() != null) {
      existingReview = doc.data()!['review'] ?? '';
    }

    final reviewController = TextEditingController(text: existingReview);
    String? errorText;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Write a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: reviewController,
                    maxLines: 5,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      hintText: 'Share your thoughts about this song',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null)
                    Text( errorText!, style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                if (existingReview.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await Favorites.instance.setReview(
                        trackId: trackId,
                        name: widget.track.name,
                        artists: widget.track.artists,
                        albumImageUrl: widget.track.albumImageUrl,
                        review: '',
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Review deleted')),
                        );
                      }
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final reviewText = reviewController.text.trim();
                    if (reviewText.isNotEmpty && ExplicitContentFilter.containsExplicitContent(reviewText)) {
                      setDialogState(() {
                        errorText = 'Your review contains inappropriate content. Please modify it.';
                      });
                      return;
                    }

                    await Favorites.instance.setReview(
                      trackId: trackId,
                      name: widget.track.name,
                      artists: widget.track.artists,
                      albumImageUrl: widget.track.albumImageUrl,
                      review: reviewText,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: reviewText.isEmpty ? const Text('Review deleted') : const Text('Review saved!')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showGlobalRatings() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reviews for "${widget.track.name}"'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('song_reviews')
                .where('trackId', isEqualTo: widget.track.id)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text('Error loading reviews'));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No reviews yet'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['username'] ?? 'Anonymous'),
                    subtitle: Text(data['review'] ?? ''),
                    trailing: data ['rating'] != null
                      ? Text((data['rating'] as num).toStringAsFixed(1) + ' ★')
                      : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return Scaffold(
      appBar: AppBar(title: const Text('Song Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (track.albumImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(track.albumImageUrl!, height: 260, fit: BoxFit.cover),
            )
          else
            const Icon(Icons.music_note, size: 140),
          const SizedBox(height: 16),
          Text(track.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(track.artists, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.favorite),
                label: Text(_isFavorite ? 'Favorited' : 'Favorite'),
                onPressed: _toggleFavorite,
              ),
              ActionChip(
                avatar: const Icon(Icons.reviews),
                label: const Text('Write Review'),
                onPressed: _showReviewDialog,
              ),
              ActionChip(
                avatar: const Icon(Icons.rate_review),
                label: const Text('View Reviews'),
                onPressed: _showGlobalRatings,
              ),
              ActionChip(
                avatar: const Icon(Icons.open_in_new),
                label: const Text('Open in Spotify'),
                onPressed: track.url != null
                    ? () async {
                        final uri = Uri.parse(track.url!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          print('Could not launch ${track.url}');
                        }
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
            const Text('Your Rating'),
            const SizedBox(height: 6),
            _StarRating(
              rating: _userRating,
              onRatingChanged: _saveRating,
            ),
            const SizedBox(height: 20),
            if (track.id != null)
              StreamBuilder<Map<String, dynamic>>(
                stream: GlobalRatings.instance.watchAverageRating(track.id!),
                builder: (context, snapshot) {
                  final average = (snapshot.data?['average'] as num?)?.toDouble() ?? 0.0;
                  final total = snapshot.data?['total'] ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public),
                    title: Text('Global Rating: ${average.toStringAsFixed(1)} / 5'),
                    subtitle: Text('$total ratings'),
                  );
                },
              ),
        ],
      ),
    );
  }
}


class _StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;

  const _StarRating({super.key, required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
     spacing: 2,
     children: List.generate(5, (index) {
        final starValue = index + 1.0;
        return IconButton(
          icon: Icon(
            rating >= starValue ? Icons.star : (rating >= starValue - 0.5 ? Icons.star_half : Icons.star_border),
            color: Colors.amber,
          ),
          onPressed: () => onRatingChanged(starValue),
        );
      }),
    );
  }
}