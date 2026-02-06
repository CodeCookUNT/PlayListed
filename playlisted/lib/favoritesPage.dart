import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'favorites.dart';
import 'main.dart' show MyAppState, StarRating;
import 'main.dart' show MyAppState;
import 'recommendations.dart';

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

  //This segment of code will appear when loading the song tab 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<MyAppState>();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinning vinyl
                SizedBox(
                  width: 200,
                  height: 200,
                  child: TweenAnimationBuilder(
                    duration: const Duration(seconds: 2),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.linear,
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 6.28319, // 2 * pi for full rotation
                        child: child,
                      );
                    },
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Vinyl grooves
                          for (int i = 1; i <= 6; i++)
                            Container(
                              width: 200 - (i * 20.0),
                              height: 200 - (i * 20.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                          // Center label
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                            child: Icon(
                              Icons.album,
                              color: theme.colorScheme.onPrimary,
                              size: 30,
                            ),
                          ),
                          // Center hole
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading songs...',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
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
                  style: theme.textTheme.titleMedium),
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
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
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
                  color: Theme.of(context).scaffoldBackgroundColor,
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
                  
                    trailing: !widget.showFavoriteIcon
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () async {
                              //remove from favorites and ratings
                              try {
                                await Favorites.instance.deleteTrack(
                                  trackId: widget.doc['id'],
                                );
                                widget.appState.markSongsForDeletion(widget.doc['id']);
                                widget.appState.removeFromLikedOrRated(widget.doc['id']);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Unliked "${widget.doc['name']}"'),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error, Couldn\'t Delete Favorited List: $e'),
                                  ),
                                );
                              }
                            },
                          )
                        : null, 
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}