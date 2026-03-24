import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'favorites.dart';
import 'loading_vinyl.dart';
import 'main.dart' show MyAppState, StarRating;

class MySongsPage extends StatelessWidget {
  MySongsPage({super.key});

    @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Liked'),
              Tab(text: 'Rated'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SongsList(
                  stream: Favorites.instance.favoritesStream(),
                  emptyMessage: 'No liked songs yet.',
                  headerLabel: '{count} liked songs:',
                ),
                SongsList(
                  stream: Favorites.instance.ratedStream(),
                  emptyMessage: 'No rated songs yet.',
                  headerLabel: '{count} rated songs:',
                  showFavoriteIcon: false,
                  
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SongsList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>> stream;
  final String emptyMessage;
  final String headerLabel;
  final bool showFavoriteIcon;

  const SongsList({
    required this.stream,
    required this.emptyMessage,
    required this.headerLabel,
    this.showFavoriteIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.read<MyAppState>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        // Show loading vinyl while waiting for data
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingVinylPage(
            labelText: 'Loading your songs...',
            ringText: ' NOW LOADING YOUR SONGS ',
          );
        }

        final items = snap.data ?? [];
        
        // Sort by updatedAt - most recent first
        items.sort((a, b) {
          final aUpdated = a['updatedAt'] as Timestamp?;
          final bUpdated = b['updatedAt'] as Timestamp?;
          
          if (aUpdated == null && bUpdated == null) return 0;
          if (aUpdated == null) return 1;
          if (bUpdated == null) return -1;
          
          return bUpdated.compareTo(aUpdated);
        });

        if (items.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(headerLabel.replaceFirst('{count}', '${items.length}'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),

            for (final doc in items)
              SlidableListItem(
                key: ValueKey(doc['id']),
                doc: doc,
                appState: appState,
                showFavoriteIcon: showFavoriteIcon,
              ),
          ],
        );
      },
    );
  }
}

// sliding widget
class SlidableListItem extends StatefulWidget {
  final Map<String, dynamic> doc;
  final MyAppState appState;
  final bool showFavoriteIcon;

  const SlidableListItem({
    super.key,
    required this.doc,
    required this.appState,
    required this.showFavoriteIcon,
  });

  @override
  State<SlidableListItem> createState() => _SlidableListItemState();
}

class _SlidableListItemState extends State<SlidableListItem> {
  double _slideOffset = 0.0;
  static const double _maxSlide = 80.0; // How far to slide
  bool hovering = false; // For hover effect on unlike button
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          // Update slide offset based on drag
          _slideOffset += details.delta.dx;
          _slideOffset = _slideOffset.clamp(-_maxSlide, 0.0);
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          if (_slideOffset < -_maxSlide / 2) {
            _slideOffset = -_maxSlide; // Snap to fully open
          } else {
            _slideOffset = 0.0; // Snap to closed
          }
        });
      },
      child: ClipRect(
        child: Stack(
          children: [
              // Red background with unlike button
              Positioned.fill(
                child: Container(
                  color: const Color.fromARGB(255, 197, 26, 10),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => hovering = true),
                    onExit: (_) => setState(() => hovering = false),
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => hovering = true);
                        // Handle unlike when button is clicked
                        try {
                          await Favorites.instance.deleteTrack(
                            trackId: widget.doc['id'],
                          );
                          widget.appState.markSongsForDeletion(widget.doc['id']);
                          widget.appState.removeFromLikedOrRated(widget.doc['id']);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unliked "${widget.doc['name']}"'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting favorite: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      // Heart icon with hover effect
                      child: SizedBox(
                        width: 40,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hovering ? Icons.heart_broken : Icons.favorite,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              //This segment of code will display information about each song
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_slideOffset, 0, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF101417)
                        : const Color(0xFFF6FAFE),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                  ),
                  child: ListTile(
                    leading: (widget.doc['albumImageUrl'] as String?) != null
                        ? Image.network(
                            widget.doc['albumImageUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              widget.showFavoriteIcon ? Icons.favorite : Icons.library_music,
                            )
                          )
                        : Icon(widget.showFavoriteIcon ? Icons.favorite : Icons.library_music), 
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.doc['name'] ?? ''),
                        Text(
                          widget.doc['artists'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        StarRating(
                          rating: (widget.doc['rating'] ?? 0).toDouble(),
                          onChanged: (r) => Favorites.instance.setRating(
                            trackId: widget.doc['id'],
                            name: widget.doc['name'],
                            artists: widget.doc['artists'],
                            albumImageUrl: widget.doc['albumImageUrl'],
                            rating: r,
                          ),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}