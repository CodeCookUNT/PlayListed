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

class UnlikeButton extends StatefulWidget {
  final Map<String, dynamic> doc;
  final MyAppState appState;

  const UnlikeButton({
    required this.doc,
    required this.appState,
  });

  @override
  State<UnlikeButton> createState() => UnlikeButtonState();
}

class UnlikeButtonState extends State<UnlikeButton> {
  
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: IconButton(
        icon: Icon( hovering ? Icons.heart_broken : Icons.favorite ),
        tooltip: hovering ? 'Unlike' : 'Liked',
        onPressed: () async {
          setState(() => hovering = true);
          try {
            await Favorites.instance.deleteTrack(
              trackId: widget.doc['id'],
            );
            widget.appState.markSongsForDeletion(widget.doc['id']);
            widget.appState.removeFromLikedOrRated(widget.doc['id']);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Unliked "${widget.doc['name']}"'),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Error deleting favorite: $e')),
              );
            }
          }
        },
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
              ListTile(
                key: ValueKey(doc['id']),
                leading: (doc['albumImageUrl'] as String?) != null
                    ? Image.network(
                        doc['albumImageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          showFavoriteIcon ? Icons.favorite : Icons.library_music,
                        )
                      )
                    : Icon(showFavoriteIcon ? Icons.favorite : Icons.library_music),
                title: Text(doc['name'] ?? ''),
                subtitle: Text(doc['artists'] ?? ''),

                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StarRating(
                      rating: (doc['rating'] ?? 0).toDouble(),
                      onChanged: (r) => Favorites.instance.setRating(
                        trackId: doc['id'],
                        name: doc['name'],
                        artists: doc['artists'],
                        albumImageUrl: doc['albumImageUrl'],
                        rating: r,
                      ),
                      size: 20,
                      spacing: 2,
                    ),
                    if (showFavoriteIcon)
                      UnlikeButton(doc: doc, appState: appState)
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () async {
                          //remove from favorites and ratings
                          try {
                            await Favorites.instance.deleteTrack(
                              trackId: doc['id'],
                            );
                            appState.markSongsForDeletion(doc['id']);
                            appState.removeFromLikedOrRated(doc['id']);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Unliked "${doc['name']}"'),
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
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}